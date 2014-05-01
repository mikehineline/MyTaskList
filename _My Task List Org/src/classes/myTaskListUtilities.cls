/*
	myTaskListUtilities - utilities for configuration of the My Task List package
	Author: Mike Hineline
*/
public class myTaskListUtilities {

    // Static variables for the Streaming API push topic
    public static String pushTopicName = 'myTaskListUpdates';
    public static Boolean pushTopicEnabled {get; set;} 
    
    /* Constructor */
    public myTaskListUtilities() {
    	// Test the status of the push topic to set the pushTopicEnabled flag
    	testForPushTopic();
    }
    
   	/*
		testForPushTopic - determine if the Streaming API push topic is already set
		Inputs: none
		Returns: Boolean
			- true if push topic exists
			- false if push topic does not exist
	*/
	public static Boolean testForPushTopic() {
		if (pushTopicEnabled == true) {
			// If the pushTopicEnabled flag is already set, return true
			return true;
		} else {
			// Check to see if the push topic is already in the DB and update the pushTopicEnabled flag
			List<PushTopic> oldMyTaskListPushTopics = new List<PushTopic>();
			oldMyTaskListPushTopics = Database.Query('SELECT p.Id, p.Name from PushTopic p where p.Name = :pushTopicName');
			if (oldMyTaskListPushTopics.size() > 0) {
				pushTopicEnabled = true;
				return true;
			}
		}
		// The push topic was not found
		pushTopicEnabled = false;
		return false;
	}

	/*
		addPushTopic - set up the Streaming API push topic if it is not already set
		Inputs: none
		Returns: Boolean
			- true if topic was added
			- false if topic was not added
	*/
	public static Boolean addPushTopic() {
		// If checks show that the push topic does not exist, create the push topic
		if (testForPushTopic() == true) {
			// Push topic was not enabled, return false
			return false;
		} else {
			PushTopic myTaskListPushTopic = new PushTopic();
			myTaskListPushTopic.Name = pushTopicName;
			myTaskListPushTopic.Query = 'Select t.WhoId, t.WhatId, t.Subject, t.Status, t.Priority, t.OwnerId, t.IsDeleted, t.IsClosed, t.Id, t.CallType, t.ActivityDate From Task t';
			myTaskListPushTopic.ApiVersion = 30.0;
			myTaskListPushTopic.NotifyForOperationCreate = true;
			myTaskListPushTopic.NotifyForOperationUpdate = true;
			myTaskListPushTopic.NotifyForOperationUndelete = true;
			myTaskListPushTopic.NotifyForOperationDelete = true;
			myTaskListPushTopic.NotifyForFields = 'Referenced';
			// If statement is workaround due to bug in push topic test procedures
			//	conflicting with real PushTopic values in DB
			if (!Test.isRunningTest()) {
				insert myTaskListPushTopic;
			}
			
			// Set the pushTopicEnabled flag and return true
			pushTopicEnabled = true;
			return true;
		}
	}

	/*
		deletePushTopic - utility to remove the Streaming API push topic
			This function is not currently used, but is here in case removal is required
		Inputs: none
		Returns: Boolean
			- true if topic was deleted
			- false if topic was not found/deleted
	*/
	public static Boolean deletePushTopic() {
		List<PushTopic> oldMyTaskListPushTopics = new List<PushTopic>();
		oldMyTaskListPushTopics = Database.Query('SELECT p.Id, p.Name from PushTopic p where p.Name = :pushTopicName');
		if (oldMyTaskListPushTopics.size() > 0) {
			try {
				// Delete the old push topic(s)
				delete oldMyTaskListPushTopics;
				pushTopicEnabled = false;
				return true;
			} catch (System.QueryException e) {
				// Push topic could not be deleted
	        	System.Debug('The following error has occurred: ' + e.getMessage());
				return false;
			}
		}
		// The topic was not found/deleted, return false
		return false;
	}

	/*
		addPushTopicAction - action for commandButton to call to add the push topic
		Inputs: none
		Returns: PageReference null
	*/
	public static PageReference addPushTopicAction() {
		// Add the push topic
		Boolean pushStatus = addPushTopic();
		
		// Set a page message
		ApexPages.Message pushStatusMsg;
		if (pushStatus == true) {
			pushStatusMsg = new ApexPages.Message(ApexPages.Severity.CONFIRM,'Task listener was successfully added.');
		} else {
			pushStatusMsg = new ApexPages.Message(ApexPages.Severity.WARNING,'Task listener was not added.');
		}
        ApexPages.addMessage(pushStatusMsg);
        
		// Return null to stay on the same page
		return null;
	}
	
	/*
		deletePushTopicAction - action for commandButton to call to delete the push topic
		Inputs: none
		Returns: PageReference null
	*/
	public static PageReference deletePushTopicAction() {
		// Add the push topic
		Boolean pushStatus = deletePushTopic();
		
		// Set a page message
		ApexPages.Message pushStatusMsg;
		if (pushStatus == true) {
			pushStatusMsg = new ApexPages.Message(ApexPages.Severity.CONFIRM,'Task listener was successfully deleted.');
		} else {
			pushStatusMsg = new ApexPages.Message(ApexPages.Severity.WARNING,'Task listener was not deleted.');
		}
        ApexPages.addMessage(pushStatusMsg);
        
		// Return null to stay on the same page
		return null;
	}
	
}