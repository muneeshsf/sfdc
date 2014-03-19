/**
 * This class contains unit tests for validating the behavior of the PositionAnnouncementTrigger
 */
@isTest(SeeAllData=true)
private class PositionAnnouncementTriggerTestClass {
	//verifyPost: Verify that chatter messages are posted when positions have the status Open/Approved
	static testMethod void verifyPost() {
		List<Position__c> openApprovedPositions = new List<Position__c>();
		 
		User hiringManager = [SELECT id, name FROM User u
					Where u.people_manager__c=true][0];   
		
		Integer startCountFeedPosts =[Select count() From CollaborationGroupFeed where parentId in (select id from CollaborationGroup where name='All Universal Containers')];
		
		System.debug(' Before trigger number of chatter posts for group is: ' + startCountFeedPosts);    
						
		for (Integer i = 1; i <=20; i++) {
			openApprovedPositions.add(new Position__c(name='Test Position #'+ i
									, hiring_manager__c=hiringManager.id
									, Job_Description__c='test position'
									, status__c='Open'
									, sub_status__c='Approved'));
		}
		Database.insert(openApprovedPositions);
		
		Integer endCountFeedPosts = [Select count() From CollaborationGroupFeed where parentId in (select id from CollaborationGroup where name='All Universal Containers')];
		System.debug('After trigger number of chatter posts for group is: ' + endCountFeedPosts);    
		System.assertEquals(startCountFeedPosts + 20, endCountFeedPosts);
	}

	//verifyNotPost: Verify that chatter messages are NOT posted when positions do not have the status Open/Approved
	static testMethod void verifyNotPost() {
		List<Position__c> positions = new List<Position__c>();
		Integer startCountFeedPosts =[Select count() From CollaborationGroupFeed where parentId in (select id from CollaborationGroup where name='All Universal Containers')];
		
		User hiringManager = [SELECT id, name FROM User u
					Where u.people_manager__c=true][0]; 
					
		String[] stati = new String[] { 'New', 'Closed', 'Open' };
		String[] substati = new String[] { 'Pending', 'Approved', 'Not Approved', 'Filled', 'Cancelled' };
		
		for(Integer i = 0; i < 20; i++) {
			String state = stati[Math.round(Math.random() * (stati.size()-1))];
			String substate = substati[Math.round(Math.random() * (substati.size()-1))];
			while(state == 'Open' && substate == 'Approved') {
				substate = substati[Math.round(Math.random() * (substati.size()-1))];
			}
			Position__c pos = new Position__c(name='Test Position #'+ i
									, hiring_manager__c=hiringManager.id
									, Job_Description__c='test position'
									, status__c=state
									, sub_status__c=substate);
		}
		
		 
		Integer endCountFeedPosts = [Select count() From CollaborationGroupFeed where parentId in (select id from CollaborationGroup where name='All Universal Containers')];
		System.assertEquals(startCountFeedPosts, endCountFeedPosts);
	}
}