/**
 * This trigger implements Universal Containers requirements for sending an
 * organization wide chatter notice when a position is in the open/approved state.
 **/
trigger PositionAnnouncementTrigger on Position__c (after insert, after update) {
	List<FeedItem> postsToAdd = new List<FeedItem>();
	List <CollaborationGroup> allUserGroup = [SELECT ID FROM CollaborationGroup WHERE Name='All Universal Containers' LIMIT 1];
	if (allUserGroup.size() == 0) {
		return;
	} 
	CollaborationGroup collabGroup = allUserGroup[0];
	
	for(Position__c position : Trigger.new) {
		if ((Trigger.isInsert
				|| position.status__c!= Trigger.oldMap.get(position.id).status__c
		  		|| position.sub_status__c!=Trigger.oldMap.get(position.id).sub_status__c)
		  	  && position.status__c == 'Open' && position.sub_status__c == 'Approved') {

			FeedItem post = new FeedItem();
			post.ParentId = collabGroup.Id;
			post.Body = 'Recommend someone for new position posted for ' + position.Name + '!!! URL: /' + position.Id;
			postsToAdd.add(post);
		}
	}
	insert postsToAdd;
}