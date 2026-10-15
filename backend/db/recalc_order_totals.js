// Corrects the stored invoice/toll totals of Round Trip orders that were saved
// before the Round Trip totals rule changed.
//
// What changed: charges entered on a Round Trip's return leg used to be left
// out of the order total (services/csvDatabaseService.js ->
// calculateOrderTotals). New and re-priced orders pick up the corrected rule
// automatically, but totals that were already stored are not recomputed.
//
// STRICTLY SCOPED. An order is only ever changed when ALL of these hold:
//   * it is a Round Trip order,
//   * the new rule gives a DIFFERENT answer than the old rule would have, and
//   * its stored totals equal what the old rule produced
//     (i.e. it is stale only because of that rule change).
// Orders whose stored totals disagree for any other reason (older rule
// versions, manual edits, ...) are listed for information and never touched.
// Only total_invoice_amount / total_toll_charges are written.
//
// SAFE BY DEFAULT: with no flags this only REPORTS and changes nothing.
//
//   node db/recalc_order_totals.js            # report only
//   node db/recalc_order_totals.js --apply    # write the corrections
//
// Honours DATA_STORE (csv | postgres) and the PG* variables from .env, the
// same way the server does.
require('dotenv').config();
const dataService = require('../services/dataService');
const csvLogic = require('../services/csvDatabaseService');

const APPLY = process.argv.includes('--apply');

function toInt(v) {
  return parseInt(v || '0', 10) || 0;
}

function parseSegments(order) {
  try {
    const parsed = JSON.parse(order.trip_segments);
    return Array.isArray(parsed) ? parsed : [];
  } catch (e) {
    return [];
  }
}

// The Round Trip invoice/toll rule as it was BEFORE the change: outbound leg
// (plus the final leg once the trip has been amended); the return leg of an
// un-amended trip was ignored.
function legacyRoundTripTotals(segments) {
  const outbound = segments[0];
  const finalLeg = segments[segments.length - 1];
  if (segments.length === 2) {
    return { invoice: toInt(outbound.invoice_amount), toll: toInt(outbound.toll_charges) };
  }
  return {
    invoice: toInt(outbound.invoice_amount) + toInt(finalLeg.invoice_amount),
    toll: toInt(outbound.toll_charges) + toInt(finalLeg.toll_charges),
  };
}

function signed(n) {
  return `${n >= 0 ? '+' : ''}${n}`;
}

async function main() {
  const orders = await dataService.readOrders();

  const toCorrect = []; // stale ONLY because of the rule change
  const needsReview = []; // affected by the rule change, but stored value matches neither rule
  const unrelated = []; // stored totals differ for reasons unrelated to this change
  let roundTripCount = 0;

  for (const order of orders) {
    const tripType = order.original_trip_type || order.trip_type || 'Single-Trip-Vendor';
    if (tripType !== 'Round-Trip-Vendor') continue;
    const segments = parseSegments(order);
    if (segments.length < 2) continue;
    roundTripCount += 1;

    // calculateOrderTotals logs per-segment detail; keep this report readable.
    const realLog = console.log;
    console.log = () => {};
    let current;
    try {
      current = csvLogic.calculateOrderTotals(order.trip_segments, tripType);
    } finally {
      console.log = realLog;
    }
    const legacy = legacyRoundTripTotals(segments);
    const stored = { invoice: toInt(order.total_invoice_amount), toll: toInt(order.total_toll_charges) };
    const now = { invoice: current.total_invoice_amount, toll: current.total_toll_charges };

    const affectedByChange = legacy.invoice !== now.invoice || legacy.toll !== now.toll;
    const storedMatchesLegacy = stored.invoice === legacy.invoice && stored.toll === legacy.toll;
    const storedMatchesNow = stored.invoice === now.invoice && stored.toll === now.toll;

    if (affectedByChange) {
      if (storedMatchesNow) continue; // already correct (re-priced after the change)
      if (storedMatchesLegacy) toCorrect.push({ order, stored, now });
      else needsReview.push({ order, stored, legacy, now });
    } else if (!storedMatchesNow) {
      unrelated.push({ order, stored, now });
    }
  }

  console.log(`Round Trip orders checked: ${roundTripCount} (of ${orders.length} total)\n`);

  console.log(`Affected by the rule change and safe to correct: ${toCorrect.length}`);
  let invoiceDelta = 0;
  let tollDelta = 0;
  for (const c of toCorrect) {
    const dInv = c.now.invoice - c.stored.invoice;
    const dToll = c.now.toll - c.stored.toll;
    invoiceDelta += dInv;
    tollDelta += dToll;
    console.log(
      `  ${c.order.order_id.padEnd(12)} status=${String(c.order.order_status).padEnd(12)} ` +
        `invoice ${c.stored.invoice} -> ${c.now.invoice} (${signed(dInv)})   ` +
        `toll ${c.stored.toll} -> ${c.now.toll} (${signed(dToll)})`
    );
  }
  if (toCorrect.length > 0) {
    console.log(`  Net effect: invoice ${signed(invoiceDelta)}, toll ${signed(tollDelta)}`);
  }

  if (needsReview.length > 0) {
    console.log(`\nAffected by the rule change but stored totals match neither rule -- NOT touched, review manually: ${needsReview.length}`);
    for (const c of needsReview) {
      console.log(
        `  ${c.order.order_id.padEnd(12)} stored ${c.stored.invoice}/${c.stored.toll}  ` +
          `old rule ${c.legacy.invoice}/${c.legacy.toll}  new rule ${c.now.invoice}/${c.now.toll}  (invoice/toll)`
      );
    }
  }

  if (unrelated.length > 0) {
    console.log(`\nStored totals differ from the rule for reasons unrelated to this change -- NOT touched: ${unrelated.length}`);
    for (const c of unrelated) {
      console.log(
        `  ${c.order.order_id.padEnd(12)} stored ${c.stored.invoice}/${c.stored.toll}  rule ${c.now.invoice}/${c.now.toll}  (invoice/toll)`
      );
    }
  }

  if (toCorrect.length === 0) {
    console.log('\nNothing to correct.');
    return;
  }
  if (!APPLY) {
    console.log('\nReport only -- nothing was changed. Re-run with --apply to write the corrections listed above.');
    return;
  }

  for (const c of toCorrect) {
    c.order.total_invoice_amount = String(c.now.invoice);
    c.order.total_toll_charges = String(c.now.toll);
    await dataService.writeOrder(c.order);
  }
  console.log(`\nApplied: ${toCorrect.length} order(s) updated.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('recalc_order_totals failed:', err);
    process.exit(1);
  });
