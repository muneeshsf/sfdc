trigger HiringManagerChatterTrigger on Position__c (after insert, after update) {
	SubscriptionsClass.HiringManagerSubscribeNewPosition(Trigger.new);	
}