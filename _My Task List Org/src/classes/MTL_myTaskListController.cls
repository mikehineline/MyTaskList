/*
	MTL_myTaskListController.cls - controller for myTaskList.page Visualforce page
		Provides a list of open tasks owned by the logged in user and methods to modify them
	Author: Mike Hineline
	
	Copyright (c) 2013, salesforce.com, Inc.
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, 
	are permitted provided that the following conditions are met:
	
	    * Redistributions of source code must retain the above copyright notice, 
	    this list of conditions and the following disclaimer.
	    * Redistributions in binary form must reproduce the above copyright notice, 
	    this list of conditions and the following disclaimer in the documentation 
	    and/or other materials provided with the distribution.
	    * Neither the name of the salesforce.com, Inc. nor the names of its contributors 
	    may be used to endorse or promote products derived from this software 
	    without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
	IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
	LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
	OF THE POSSIBILITY OF SUCH DAMAGE.
*/
global with sharing class MTL_myTaskListController {
	// Member variable to limit SOQL query results in task queries
	private static final Integer TASK_QUERY_LIMIT = 1000;
	
	// Member variable to hold the list of Tasks and related info
	public List<TaskContainer> myTaskList {get; private set;}

	// Member variables to hold task sorting onClick scripts
	public String orgHost {get; private set;}
	public String taskSortDateASCScript {get; private set;}
	public String taskSortDateDESCScript {get; private set;}
	public String taskSortPriorityScript {get; private set;}
    public String taskFilterAllOpenScript {get; private set;}
    public String taskFilterOverdueScript {get; private set;}
    public String taskFilterTodayScript {get; private set;}
    public String taskFilterTodayPlusOverdueScript {get; private set;}
    public String taskFilterTomorrowScript {get; private set;}
    public String taskFilterNext7DaysScript {get; private set;}
    public String taskFilterNext7DaysPlusOverdueScript {get; private set;}
    public String taskFilterThisMonthScript {get; private set;}

   	// pageFormat will store the type of page rendered and affect how URLs work
   	//	aloha [default] => aloha (standard) UI with standard hyperlinks
   	//	mobile = Salesforce1 browser => standard hyperlinks
   	//	console = sales/service cloud console => console javascript used to open hyperlinks
    public String pageFormat {get; private set;}
    
	/*
		Constructor to initialize the Task list including member variables and the list of Task sObjects
	*/
    public MTL_myTaskListController()
    {
    	/*
    		Initialize the page format to determine if this is the console, Salesforce1 mobile, or Aloha UI
    	*/
    	// Determine the page rendering location (default to aloha)
		String pageisdtp = ApexPages.currentPage().getParameters().get('isdtp');
		if (pageisdtp == 'nv' || pageisdtp == 'vw') {
			pageFormat = 'console';
		} else if (pageisdtp == 'p1') {
			pageFormat = 'mobile';	
		} else {
			pageFormat = 'aloha';
		}

    	/*
    		Initialize the sort and filter onClick scripts
    	*/
    	// Get the current task sort order and filter from the page GET parameters
    	String getSortOrder = ApexPages.currentPage().getParameters().get('so');
    	if (getSortOrder == '' || getSortOrder == null) getSortOrder = 'dateASC';
    	String getFilter = ApexPages.currentPage().getParameters().get('flt');
    	if (getFilter == '' || getFilter == null) getFilter = 'allopen';
		// Set the base URL for this page
		orgHost = MTL_myTaskListController.calculateOrgHost();
        String thisPage = orgHost + System.URL.getCurrentRequestUrl().getPath();
    	// Initialize the sort onClick scripts
    	taskSortDateASCScript = 'https://' + thisPage + '?so=dateASC&flt=' + getFilter + '&isdtp=' + pageisdtp;
    	taskSortDateDESCScript = 'https://' + thisPage + '?so=dateDESC&flt=' + getFilter + '&isdtp=' + pageisdtp;
    	taskSortPriorityScript = 'https://' + thisPage + '?so=priorityASC&flt=' + getFilter + '&isdtp=' + pageisdtp;
    	// Initialize the filter onClick scripts
        taskFilterAllOpenScript ='https://' + thisPage + '?flt=allopen&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterOverdueScript ='https://' + thisPage + '?flt=overdue&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterTodayScript ='https://' + thisPage + '?flt=today&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterTodayPlusOverdueScript ='https://' + thisPage + '?flt=todayplusoverdue&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterTomorrowScript ='https://' + thisPage + '?flt=tomorrow&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterNext7DaysScript ='https://' + thisPage + '?flt=next7days&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterNext7DaysPlusOverdueScript ='https://' + thisPage + '?flt=next7daysplusoverdue&so=' + getSortOrder + '&isdtp=' + pageisdtp;
        taskFilterThisMonthScript ='https://' + thisPage + '?flt=thismonth&so=' + getSortOrder + '&isdtp=' + pageisdtp;

    	// Default to ascending by activity date (i.e. due date) (to put closest due dates on top)
    	// 	and then ascending by priority (to put high on top)
    	String taskSortOrder;
    	if (getSortOrder == 'dateDESC') {
    		taskSortOrder = 't.ActivityDate DESC, t.Priority ASC';
    	} else if (getSortOrder == 'priorityASC') {
    		taskSortOrder = 't.Priority ASC, t.ActivityDate ASC';
    	} else {
    		taskSortOrder = 't.ActivityDate ASC, t.Priority ASC';
    	}
    	// Get the task filter from the page GET parameters
    	// Default to all open
    	String taskFilter;
    	if (getFilter == 'overdue') {
    		taskFilter = ' AND t.ActivityDate < TODAY';
    	} else if (getFilter == 'today') {
    		taskFilter = ' AND t.ActivityDate = TODAY';
    	} else if (getFilter == 'todayplusoverdue') {
    		taskFilter = ' AND t.ActivityDate <= TODAY';
    	} else if (getFilter == 'tomorrow') {
    		taskFilter = ' AND t.ActivityDate = TOMORROW';
    	} else if (getFilter == 'next7days') {
    		taskFilter = ' AND t.ActivityDate = NEXT_N_DAYS:7';
    	} else if (getFilter == 'next7daysplusoverdue') {
    		taskFilter = ' AND (t.ActivityDate < TODAY OR t.ActivityDate = NEXT_N_DAYS:7)';
    	} else if (getFilter == 'thismonth') {
    		taskFilter = ' AND t.ActivityDate = THIS_MONTH';
    	} else {
    		// default all open
    		taskFilter = '';
    	}
    	
        // Create a activity wrapper sObject to contain the Task + Account info
    	myTaskList = new List<TaskContainer>();
    	
    	// Generate a list of all Tasks assigned to (via OwnerId) the logged in user
    	String myTaskQueryString = 'SELECT t.Id, t.OwnerId, t.ActivityDate, t.Subject, t.Priority, t.Status, t.Description, t.Type, t.CreatedDate, t.WhoId, t.Who.Name, t.WhatId, t.What.Name, t.AccountId, t.IsClosed';
        myTaskQueryString += ' FROM Task t';
		myTaskQueryString += ' WHERE t.IsClosed = false';
		myTaskQueryString += ' AND t.OwnerID = \'' + UserInfo.getUserId() + '\'';
		myTaskQueryString += taskFilter;
		myTaskQueryString += ' ORDER BY ' + taskSortOrder;
		myTaskQueryString += ' LIMIT ' + TASK_QUERY_LIMIT;
		List<Task> myTasks = Database.query(myTaskQueryString);
		
        // Fill member variable myTaskList with the user's events
        if (myTasks.size() > 0) {
        	for(Task t : myTasks) {
        		myTaskList.add( new TaskContainer(t,this) );
        	}
        }
    }

	/*
		TaskContainer - class for storing Task sObject & related information
	*/
    public class TaskContainer {
    	// Getter/Setter for the contained Task sObject
        public Task taskSObject {get; private set;}
        // Member variable for the header CSS class addition of a card when the priority is high
        public String priorityPanelClass {get; private set;}
        // Member variable for the header CSS class addition of a card when the priority is high
        public String priorityIconClass {get; private set;}
        // Member variable for the CSS class addition to highlight the task due date
        public String dueDateStyle {get; private set;}

        // Overloaded constructor to initialize the date when given an Task
        public TaskContainer(Task t, MTL_myTaskListController theController) {
            taskSObject = t;
			/*
				Initialize various UI features such as formatting options for this task
			*/
            // Define the CSS class addition for the panel based on case priority; by default, no modification is made
            priorityPanelClass = '';
            // Define the CSS class addition based on case priority; by default, the priority icon is hidden
            priorityIconClass = 'hidden';
            // Define the CSS class addition based on due date; by default, no modification is made
            dueDateStyle = '';

            if (t.Priority.toLowerCase() == 'high') {
	            // If priority is high, apply Bootstrap CSS class for a red panel header
            	priorityPanelClass = ' panel-danger';
	            // If priority is high, do not apply the hidden class
            	priorityIconClass = '';
            }
            if (t.ActivityDate <= System.Date.today()) {
	            // If the ActivityDate is <= today, apply Bootstrap CSS class text class for red text
            	dueDateStyle = 'text-danger';
            }
        }
    }

	/*
		calculateOrgHost - return the Salesforce host name (POD.salesforce.com or MYDOMAIN.my.salesforce.com)
		Inputs: none
		Returns: String thisOrgHost
	*/
	static String calculateOrgHost() {
		String thisOrgHost;
		String baseURLHost = System.URL.getSalesforceBaseUrl().getHost();
		// Split up the derived hostname using the period as a delimiter
		List<String> urlParts = baseURLHost.replace('-api','').split('\\.');
       	if (urlParts.size() == 3) thisOrgHost = urlParts[0] + '.salesforce.com';  // Salesforce base URL
       	else if (urlParts.size() == 4 && urlParts[1] == 'my') thisOrgHost = baseURLHost; // MyDomain base URL
       	else if (urlParts.size() == 5 && urlParts[2] == 'my') thisOrgHost = baseURLHost; // Sandbox MyDomain base URL
       	else if (urlParts.size() == 5) thisOrgHost = urlParts[1] + '.salesforce.com'; // Visualforce base URL
        return thisOrgHost;
	}
	
	/*
		Remoting method to update a Task record
		Inputs:
		- ID recordID - ID of the record to update
		- String targetField - API name of the field to update (null if just getting the updated task from the DB)
		- String newValue - new value to store in targetField (null if just getting the updated task from the DB)
		Returns:
		- Task - the updated Task sObject
	*/
	@RemoteAction
	global static Task updateTask(ID recordID, String targetField, String newValue) {
		// Get the sObject from the input recordID
		Task thisTask = [SELECT t.Id, t.OwnerId, t.ActivityDate, t.Subject, t.Priority, t.Status, 
						t.Description, t.Type, t.CreatedDate, t.WhoId, t.Who.Name, t.WhatId, t.What.Name,
						t.AccountId, t.IsClosed, t.IsDeleted  
						FROM Task t
						WHERE t.Id = :recordID
						LIMIT :TASK_QUERY_LIMIT
						ALL ROWS];
		
		// Determine if we should perform the DML update operation; by default, do not unless we get a valid targetField
		Boolean performDML = false;
		// Determine if the record needs to be requeried when finished; by default, it will not be
		Boolean reQueryRecord = false;
		
		// Update the appropriate targetField
		if (targetField == 'Status') {
			thisTask.Status = newValue;
			// Trigger the DML update
			performDML = true;
			// Trigger querying the sObject again to ensure calculated field IsClosed is up to date
			reQueryRecord = true;
		} else if (targetField == 'Priority') {
			thisTask.Priority = newValue;
			// Trigger the DML update
			performDML = true;
		} else if (targetField == null || targetField == '') {
			// Reiterate no DML update and no requery; just passing the object back
			performDML = false;
			reQueryRecord = false;
		} else {
			System.debug(LoggingLevel.ERROR, 'ERROR: Unknown targetField was passed');
			return null;
		}
		
		// Perform the DML update
		if (performDML) {
			try {
				update thisTask;	
			} catch (DmlException e) {
				System.debug(LoggingLevel.ERROR, e.getMessage());
				return null;
			}
		}

		// Get the sObject again to ensure calculated fields cush as IsClosed are up to date
		if (reQueryRecord) {
			thisTask = [SELECT t.Id, t.OwnerId, t.ActivityDate, t.Subject, t.Priority, t.Status, 
						t.Description, t.Type, t.CreatedDate, t.WhoId, t.Who.Name, t.WhatId, t.What.Name,
						t.AccountId, t.IsClosed, t.IsDeleted  
						FROM Task t
						WHERE t.Id = :recordID];
		}
		
		// Return the Task sObject
		return thisTask;
		
	}
	
	/*
		emailTask - Remoting method to send a task to the logged in User via e-mail
		Inputs:
		- ID recordID - ID of the record to send
		Returns:
		- Boolean success - true if the mail send was successful / false if there is a sending exception
	*/
	@RemoteAction
	global static Boolean emailTask(ID recordID) {
		// Get the sObject from the input recordID
		Task thisTask = [SELECT t.Id, t.OwnerId, t.ActivityDate, t.Subject, t.Priority, t.Status, 
						t.Description, t.Type, t.CreatedDate, t.WhoId, t.Who.Name, t.WhatId, t.What.Name,
						t.AccountId, t.IsClosed, t.IsDeleted  
						FROM Task t
						WHERE t.Id = :recordID];
		
		// If the task was not found, return false
		if(thisTask == null) {
			return false;
		}

		// Get the base URL for object links
		String orgHost = MTL_myTaskListController.calculateOrgHost();
		String thisTaskBaseURL = 'https://' + orgHost + '/';

		/*
			Construct the e-mail reminder message
		*/
		// Send the message to the current user and set appropriate messaging defaults
		// use setTargetObjectId instead of setToAddressses to avoid SingleEmailMessage governer limit
		Messaging.SingleEmailMessage thisMail = new Messaging.SingleEmailMessage();
        thisMail.setTargetObjectId(UserInfo.getUserId());
        thisMail.setSaveAsActivity(false);
        thisMail.setUseSignature(false);
		// Set the e-mail subject
        String thisSubject = 'REMINDER: ' + thisTask.Subject;
        thisMail.setSubject(thisSubject);
        // Construct the e-mail HTML and Plain Text bodies
        String thisHTMLBody = 'Reminder for task: <a href="' + thisTaskBaseURL + thisTask.Id + '">' + thisTask.Subject + '</a><br /><br />';
        String thisPlainTextBody = 'Reminder for task: ' + thisTask.Subject + ' (' + thisTaskBaseURL + thisTask.Id + ')\n\n';
        if (thisTask.ActivityDate != null) {
        	thisHTMLBody += 'Due: ' + thisTask.ActivityDate.format() + '<br />';
        	thisPlainTextBody += 'Due: ' + thisTask.ActivityDate.format() + '\n';
        }
        if (thisTask.whatId != null) {
        	thisHTMLBody += 'RE: <a href="' + thisTaskBaseURL + thisTask.WhatId + '">' + thisTask.What.Name + '</a><br />';
        	thisPlainTextBody += 'RE: ' + thisTask.What.Name + ' (' + thisTaskBaseURL + thisTask.WhatId + ')\n';
        }
		if (thisTask.Status != null && thisTask.Status != '') {
        	thisHTMLBody += 'Status: ' + thisTask.Status + '<br />';
        	thisPlainTextBody += 'Status: ' + thisTask.Status + '\n';
		}
		if (thisTask.Type != null && thisTask.Type != '') {
        	thisHTMLBody += 'Type: ' + thisTask.Type + '<br />';
        	thisPlainTextBody += 'Type: ' + thisTask.Type + '\n';
		}
		if (thisTask.WhoId != null) {
        	thisHTMLBody += 'Who: <a href="' + thisTaskBaseURL + thisTask.WhoId + '">' + thisTask.Who.Name + '</a><br />';
        	thisPlainTextBody += 'Who: ' + thisTask.Who.Name + ' (' + thisTaskBaseURL + thisTask.WhoId + ')\n';
		}
		if (thisTask.Description != null && thisTask.Description != '') {
			String thisHTMLDescription = thisTask.Description.replace('\r','<br />');
        	thisHTMLBody += 'Description: <br />' + thisHTMLDescription + '<br />';
        	thisPlainTextBody += 'Description: \n' + thisTask.Description + '\n';
		}
        // Assemble the mail
        thisMail.setHtmlBody(thisHTMLBody);
        thisMail.setPlainTextBody(thisPlainTextBody);
        // Send the mail
        try {
        	Messaging.SendEmailresult[] mailResult = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { thisMail }); 
        } catch (System.EmailException e) {
        	System.Debug('The following error has occurred: ' + e.getMessage());
        	return false;
        }
		
		return true;
	}
	
}