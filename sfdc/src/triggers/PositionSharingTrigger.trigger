/**
 * This trigger implements Universal Containers requirements for programmatic sharing,
 * allowing hiring managers permissions on position objects depending on the stage of the 
 * position.
 * Other sharing rules, such as org-wide sharing permissions based on object stage, are
 * set declaratively.
 **/
trigger PositionSharingTrigger on Position__c (after insert, after update) {
/** 
 * When a Position record is modified, make sure the sharing rules on the record match 
 * the status fields:
 *   If Status/sub-status = open/approved
 *		- Hiring Manager = Edit
 *		- All others in organization = Read
 *	 Else
 *		- Hiring Manager = Read
 *		- All others in organization = No Access
 * NOTE: Because the Hiring Manager may have been changed on an update, we need to make sure
 *  that any sharing rules for the old Hiring Manager are removed.
*/
	
	// Map of Position ID --> New Hiring Mgr Id				
	Map<ID,ID> posIdToNewMgrIdMap = new Map<ID,ID>();			
	// A list of records that we are accumulating to put in the database.
	List<sObject> sharesToInsert = new List<sObject>(); 
	
	//Loop through records that in the trigger and:
	for(Position__c pos : Trigger.new) {
		boolean isUpdate = Trigger.oldMap != null;
		Position__c oldPos = isUpdate ? Trigger.oldMap.get(pos.Id) : null;
		// if this an update,
		// if hiring manager changed
		if(isUpdate && oldPos.Hiring_Manager__c != pos.Hiring_Manager__c) {
			// store record in a map (posIdtoNewMgrIdMap) with key = position record id, value = new hiring manager id
			posIdToNewMgrIdMap.put(pos.Id, pos.Hiring_Manager__c);
		}
		// if this is insert or the status or substatus of the record has changed or the hiring manager has changed
		if(!isUpdate || oldPos.Status__c != pos.Status__c || oldPos.Sub_Status__c != pos.Status__c) {
			// create a Position__share record for the hiring manager, setting common fields: 
			// parentId to id of current position (the object on which share is being set)
			// userOrGroupId to the hiring manager (the user for who is being given access)
			// rowCause to Schema.Position__Share.RowCause.Hiring_Manager__c
			// if Status/sub-status = open/approved
			//   set accessLevel field of the Position__share record to the string value Edit
			// else
			//   set accessLevel field of the Position__share record to the string value Read
			// add the Position__Share record to the sharestToInsert list	
			sharesToInsert.add(new Position__Share(
									parentId = pos.Id, 
									userOrGroupId = pos.Hiring_Manager__c,
									rowCause = Schema.Position__Share.RowCause.Hiring_Manager__c,
									accessLevel = (pos.Status__c == 'Open' && pos.Sub_Status__c == 'Approved') ? 'Edit' : 'Read'));
		}
	}
	if (posIdToNewMgrIdMap!=null && posIdToNewMgrIdMap.size() > 0 ) {
		PositionSharingClass.deletePositionSharingByRowCause(posIdToNewMgrIdMap, 'Hiring_Manager__c');		
	}
	// Insert the new share objects in the DB 
	Database.insert(sharesToInsert);		
}