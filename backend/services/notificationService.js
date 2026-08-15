const csvService = require('./dataService');

/**
 * Determine recipients for a new order
 * For new orders, the next in-scope department is Accounts Team
 */
function determineRecipientsForNewOrder(order) {
  return ['Accounts Team'];
}

/**
 * Determine recipients for an approved order based on facility units
 * Maps facility units to Security and Stores departments
 */
function determineRecipientsForApprovedOrder(order) {
  const recipients = new Set();
  
  // Extract facility units from order segments
  const facilityUnits = new Set();
  
  // Parse segments to find facility units
  let segments = [];
  if (order.trip_segments) {
    if (typeof order.trip_segments === 'string') {
      try {
        segments = JSON.parse(order.trip_segments);
      } catch (e) {
        console.error('Error parsing trip_segments:', e);
      }
    } else if (Array.isArray(order.trip_segments)) {
      segments = order.trip_segments;
    }
  }
  
  // Extract locations from segments
  segments.forEach(segment => {
    if (segment.source) {
      facilityUnits.add(segment.source);
    }
    if (segment.destination) {
      facilityUnits.add(segment.destination);
    }
  });
  
  // Also check top-level source and destination
  if (order.source) {
    facilityUnits.add(order.source);
  }
  if (order.destination) {
    facilityUnits.add(order.destination);
  }
  
  // Map facility units to departments
  facilityUnits.forEach(location => {
    const locationLower = location.toLowerCase();
    
    // Unit-1 mapping
    if (locationLower.includes('unit-1') || locationLower.includes('unit 1') || 
        locationLower.includes('unit-i') || locationLower.includes('unit i')) {
      recipients.add('Security-Factory 1');
      recipients.add('Stores IAF Unit-1/ Soliflex unit-1');
      recipients.add('Fabric IAF unit-1 / Soliflex unit-1');
    }
    
    // Unit-2 mapping
    if (locationLower.includes('unit-2') || locationLower.includes('unit 2') || 
        locationLower.includes('unit-ii') || locationLower.includes('unit ii')) {
      recipients.add('Security-Factory 2');
      recipients.add('Stores Unit-IV/ soliflex unit-II');
    }
    
    // Unit-3 mapping
    if (locationLower.includes('unit-3') || locationLower.includes('unit 3') || 
        locationLower.includes('unit-iii') || locationLower.includes('unit iii')) {
      recipients.add('Security-Factory 3');
      recipients.add('Soliflex Unit-III');
      recipients.add('Fabric Solifelx unit-III');
    }
    
    // Unit-4 mapping
    if (locationLower.includes('unit-4') || locationLower.includes('unit 4') || 
        locationLower.includes('unit-iv') || locationLower.includes('unit iv') ||
        locationLower.includes('iaf unit-4') || locationLower.includes('iaf unit 4')) {
      recipients.add('Security-Factory 4');
      recipients.add('Stores Unit-IV/ soliflex unit-II');
      recipients.add('Fabric Unit-IV/ Soliflex unit-II');
    }
    
    // Generic Soliflex unit matching
    if (locationLower.includes('soliflex unit-1') || locationLower.includes('soliflex unit 1')) {
      recipients.add('Security-Factory 1');
      recipients.add('Stores IAF Unit-1/ Soliflex unit-1');
    }
    if (locationLower.includes('soliflex unit-2') || locationLower.includes('soliflex unit 2')) {
      recipients.add('Security-Factory 2');
      recipients.add('Stores Unit-IV/ soliflex unit-II');
    }
    if (locationLower.includes('soliflex unit-3') || locationLower.includes('soliflex unit 3')) {
      recipients.add('Security-Factory 3');
      recipients.add('Soliflex Unit-III');
    }
  });
  
  return Array.from(recipients);
}

/**
 * Create notification for a department
 */
async function createNotification(orderId, recipientDepartment, notificationType, message, relatedUserId = '') {
  return await csvService.writeNotification({
    orderId: orderId,
    recipientDepartment: recipientDepartment,
    notificationType: notificationType,
    message: message,
    status: 'unread',
    createdAt: csvService.getISTTimestamp(),
    relatedUserId: relatedUserId
  });
}

/**
 * Create notifications for new order
 */
async function notifyNewOrder(order) {
  const recipients = determineRecipientsForNewOrder(order);
  const notifications = [];
  
  for (const department of recipients) {
    const notification = await createNotification(
      order.order_id || order.orderId,
      department,
      'ORDER_CREATED',
      `New order created, pending for approval. Order ID: ${order.order_id || order.orderId}`,
      order.creator_user_id || order.creatorUserId || ''
    );
    notifications.push(notification);
  }
  
  return notifications;
}

/**
 * Create notifications for approved order
 */
async function notifyApprovedOrder(order) {
  const recipients = determineRecipientsForApprovedOrder(order);
  const notifications = [];
  
  // Extract facility units for message context
  let facilityUnits = [];
  let segments = [];
  if (order.trip_segments) {
    if (typeof order.trip_segments === 'string') {
      try {
        segments = JSON.parse(order.trip_segments);
      } catch (e) {
        console.error('Error parsing trip_segments:', e);
      }
    } else if (Array.isArray(order.trip_segments)) {
      segments = order.trip_segments;
    }
  }
  
  segments.forEach(segment => {
    if (segment.source && !facilityUnits.includes(segment.source)) {
      facilityUnits.push(segment.source);
    }
    if (segment.destination && !facilityUnits.includes(segment.destination)) {
      facilityUnits.push(segment.destination);
    }
  });
  
  const facilityContext = facilityUnits.length > 0 ? facilityUnits.join(', ') : 'facility';
  
  for (const department of recipients) {
    let message = '';
    const deptLower = department.toLowerCase();
    
    if (deptLower.includes('security')) {
      message = `Vehicle entry/exit notification for ${facilityContext}. Order ID: ${order.order_id || order.orderId}`;
    } else if (deptLower.includes('stores') || deptLower.includes('fabric')) {
      message = `Material verification required for ${facilityContext}. Order ID: ${order.order_id || order.orderId}`;
    } else {
      message = `Order approved and requires your attention. Order ID: ${order.order_id || order.orderId}`;
    }
    
    const notification = await createNotification(
      order.order_id || order.orderId,
      department,
      'ORDER_APPROVED',
      message,
      order.creator_user_id || order.creatorUserId || ''
    );
    notifications.push(notification);
  }
  
  return notifications;
}

/**
 * Notify the next relevant department after a single checkpoint stage is
 * approved (Security-Entry -> Stores-Verification -> Security-Exit,
 * chaining across segments). Uses the same site-key location matching as
 * the workflow permission check (csvService.extractLocationKey /
 * departmentsForLocationKey) so notification targets and who's actually
 * allowed to act on that checkpoint never drift apart. Silently no-ops if a
 * location has no registered department (e.g. a factory unit with no
 * registered Security/Stores staff yet) -- never throws, callers should
 * treat this as best-effort and non-blocking for the underlying approval.
 *
 * @param order the order (for order_id / creator context)
 * @param stage the stage that was just approved: 'SECURITY_ENTRY' | 'STORES_VERIFICATION' | 'SECURITY_EXIT'
 * @param workflowStep the specific workflow step object that was approved (carries .location, .stage_index)
 * @param segments the order's full trip_segments array
 * @param segmentIndex index of the segment this stage belongs to, within `segments`
 * @param isOrderCompleted whether this approval made the whole order COMPLETED
 */
async function notifyNextCheckpoint(order, stage, workflowStep, segments, segmentIndex, isOrderCompleted) {
  const orderId = order.order_id || order.orderId;
  const relatedUserId = order.creator_user_id || order.creatorUserId || '';
  const location = workflowStep?.location || '';

  const notifyDepartments = async (departments, notificationType, message) => {
    const notifications = [];
    for (const department of departments) {
      notifications.push(await createNotification(orderId, department, notificationType, message, relatedUserId));
    }
    return notifications;
  };

  const securityAt = (loc) => {
    const key = csvService.extractLocationKey(loc);
    return csvService.departmentsForLocationKey(key).filter((d) => d.toLowerCase().includes('security'));
  };
  const storesAt = (loc) => {
    const key = csvService.extractLocationKey(loc);
    return csvService.departmentsForLocationKey(key, { includeFabric: true }).filter(
      (d) => d.toLowerCase().includes('stores') || d.toLowerCase().includes('fabric')
    );
  };

  if (stage === 'SECURITY_ENTRY') {
    const depts = storesAt(location);
    if (depts.length === 0) return [];
    return notifyDepartments(depts, 'CHECKPOINT_STORES_VERIFICATION',
      `Stores verification required at ${location}. Order ID: ${orderId}`);
  }

  if (stage === 'STORES_VERIFICATION') {
    const depts = securityAt(location);
    if (depts.length === 0) return [];
    return notifyDepartments(depts, 'CHECKPOINT_SECURITY_EXIT',
      `Security exit approval required at ${location}. Order ID: ${orderId}`);
  }

  if (stage === 'SECURITY_EXIT') {
    const stageIndex = workflowStep?.stage_index;
    // Origin-side exit (stage_index 2) hands off to this same segment's
    // destination-side entry (stage_index 3).
    if (stageIndex === 2) {
      const destLocation = segments[segmentIndex]?.destination || '';
      const depts = securityAt(destLocation);
      if (depts.length === 0) return [];
      return notifyDepartments(depts, 'CHECKPOINT_SECURITY_ENTRY',
        `Vehicle en route, security entry required at ${destLocation}. Order ID: ${orderId}`);
    }
    // Destination-side exit (stage_index 5): either the order is now fully
    // complete, or hand off to the next segment's origin-side entry.
    if (isOrderCompleted) {
      return notifyDepartments(['Accounts Team'], 'ORDER_COMPLETED',
        `Order fully completed. Order ID: ${orderId}`);
    }
    if (segmentIndex + 1 < segments.length) {
      const nextSource = segments[segmentIndex + 1]?.source || '';
      const depts = securityAt(nextSource);
      if (depts.length === 0) return [];
      return notifyDepartments(depts, 'CHECKPOINT_SECURITY_ENTRY',
        `Vehicle en route to next segment, security entry required at ${nextSource}. Order ID: ${orderId}`);
    }
  }

  return [];
}

/**
 * Notify Accounts Team, Admin, and the order's creator (via their
 * department, since notifications are department-scoped in this system)
 * when an order/checkpoint is rejected. No existing precedent for this in
 * the codebase -- this is a new notification, not a fix to an existing one.
 */
async function notifyOrderRejected(order, workflowStep, comments) {
  const orderId = order.order_id || order.orderId;
  const relatedUserId = order.creator_user_id || order.creatorUserId || '';
  const location = workflowStep?.location || '';
  const recipients = new Set(['Accounts Team', 'Admin']);
  if (order.creator_department) recipients.add(order.creator_department);

  const message = `Order rejected${location ? ` at ${location}` : ''}. Reason: ${comments || 'Not provided'}. Order ID: ${orderId}`;
  const notifications = [];
  for (const department of recipients) {
    notifications.push(await createNotification(orderId, department, 'ORDER_REJECTED', message, relatedUserId));
  }
  return notifications;
}

module.exports = {
  determineRecipientsForNewOrder,
  determineRecipientsForApprovedOrder,
  createNotification,
  notifyNewOrder,
  notifyApprovedOrder,
  notifyNextCheckpoint,
  notifyOrderRejected
};

