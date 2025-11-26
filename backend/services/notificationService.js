const csvService = require('./csvDatabaseService');

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
    createdAt: new Date().toISOString(),
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

module.exports = {
  determineRecipientsForNewOrder,
  determineRecipientsForApprovedOrder,
  createNotification,
  notifyNewOrder,
  notifyApprovedOrder
};

