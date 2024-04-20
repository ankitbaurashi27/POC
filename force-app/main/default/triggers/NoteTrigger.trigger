trigger NoteTrigger on Note__c (after delete, 
        after undelete
        ) 
{ 
        new NoteTriggerHandler().run();
}