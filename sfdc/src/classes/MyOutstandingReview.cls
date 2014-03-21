public class MyOutstandingReview {
    
    // TODO: Declare a "checked" Boolean property to track if this record has been checked
    public Boolean Checked { get; set; }
    // TODO: Declare a "review" property to include the original review record in this wrapped object     
    public Review__c Review { get; set; }
    
    // TODO: Declare a no-argument constructor that instantiates a new review and sets "checked" to false
    public MyOutstandingReview() {
    	this(new Review__c());
    }

    // TODO: Declare a one-argument constructor that wraps an existing review and sets "checked" to false
    public MyOutstandingReview(Review__c aReview) {
    	Review = aReview;
    	Checked = false;
    }
    
}