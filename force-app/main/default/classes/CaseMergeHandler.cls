/**
* @File Name : CaseMergeHandler.cls
* @Description : Test Class : CaseMergeHandlerTest
* @Author :
* @Last Modified By :
* @Last Modified On : November 26, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 26, 2024 |   | Initial Version
**/

public without sharing class CaseMergeHandler {

    public static Set<String> fieldSet = new Set<String>();
    public static Set<String> lookupfieldSet = new Set<String>();
    public static Map<String, String> fieldLabels = new Map<String, String>();
    public static Map<String, String> fieldMetadata = new Map<String, String>();
    public static List<String> invalidStatuses = new List<String>{ 'Merged', 'Closed' };
    public static String fieldList = '';
    public static Set<String> specialtyTeamNames = new Set<String>{'Connected Technology Specialist', 'Incident', 'Resolution', 'InTouchCX Escalation', 'June Oven', 'Order Management', 'NPD Contacts', 'Pellet', 'Service', 'Social and Reviews'};
    public static Set<String> specialtyTeamRoles = new Set<String>{'Incident_Agent', 'Pellet_Connected_Agent', 'NPD_Agent', 'Order_Management_Agent', 'Resolution_Agent', 'Social_Review_Agent', 'June_Oven_Agent'};
    public static Set<String> specialtyTeamRoleUserRoleName = new Set<String>{ 'Incident', 'Service Support', 'NPD', 'Order Management', 'Pellet', 'Resolution', 'Social', 'Review', 'June', 'Connected', 'Intouchcx Supervisor', 'Consumer'};
    public static Map<String, String> caseOwnerMappings = new Map<String, String>{
        'Incident' => 'Incident',
        'Service Support' => 'Service',
        'NPD' => 'NPD Contacts',
        'Order Management' => 'Order Management',
        'Pellet' => 'Pellet',
        'Resolution' => 'Resolution',
        'Social' => 'Social and Reviews',
        'Review' => 'Social and Reviews',
        'June' => 'June Oven',
        'Connected' => 'Connected Technology Specialists',
        'InTouchCX Supervisor' => 'InTouchCX Escalation'
    };
	public static Set<String> dateRelatedFields = new Set<String>();

	@AuraEnabled(cacheable=true)
    public static Map<String, Object> getSelectedRecords(String recordIds) {
        Map<String, Object> response = new Map<String, Object>();
        try{
            List<String> recordIdList = (List<String>) JSON.deserialize(recordIds, List<String>.class);

            if (!FeatureManagement.checkPermission('Merge_Case')) {
                response.put('error', 'You do not have permission to merge cases.');
                return response;
            }
            
            if (recordIdList.size() == 1 || recordIdList.size() >= 3 ) {
                response.put('error', 'Choose upto 2 records to perform case merge.');
                return response;
            }

            List<Case> cases = getCaseRecord(recordIdList);

            if (cases[0].AccountId != cases[1].AccountId) {
                response.put('error', 'Cases must belong to the same account to be merged.');
                return response;
            }

            for(Case c: cases){
                if (invalidStatuses.contains(c.Status) ) {
                    response.put('error', 'Only cases with a status below "Solved" can be merged.');
                    return response;
                } 
            }
    
            String userSpecialtyTeam  = isSpecialityTeam(UserInfo.getUserId());
            Boolean isSpecialtyTeamUser = userSpecialtyTeam != 'Non-Specialty';
			Set<String> specialtyTeams = checkSpecialityTeamCase(new Set<Id>{cases[0].Id,cases[1].Id});
            if(isSpecialtyTeamUser){
                for(String str: specialtyTeams){
                    if(str != userSpecialtyTeam){
                        response.put('error', 'Cases owned by different specialty teams, cannot be merged.');
                        return response;
                    }
                }
            }else{
                if (specialtyTeams.size() > 1 ) { 
                    response.put('error', 'You cannot merge cases owned by specialty teams.');
                    return response;
                }
            }

            List<Map<String, Object>> caseDetails = new List<Map<String, Object>>();

            for (Case c : cases) {
                Map<String, Object> record = new Map<String, Object>();
                for(String fieldApiName : fieldSet){
                    if (fieldApiName.contains('.')) {
                        String[] parts = fieldApiName.split('\\.');
                        if (parts.size() == 2) {
                            String relatedObject = parts[0]; 
                            String relatedField = parts[1]; 
                             if (c.getSObject(relatedObject) != null) {
                                Object fieldValue = c.getSObject(relatedObject).get(relatedField);
                                if (!record.containsKey(fieldApiName)) {
                                    record.put(fieldApiName, fieldValue);
                                }
                            } else {
                                record.put(fieldApiName, null);
                            }
                        }
                    }else{
                        if(c.get(fieldApiName) != null){
							Object fieldValue = c.get(fieldApiName);
                            if(dateRelatedFields.contains(fieldApiName)){
                                fieldValue = ((DateTime) fieldValue).format('MM/dd/yyyy');
                            }
                            record.put(fieldApiName, fieldValue);
                        }
                    }
                }
                caseDetails.add(record);
            }

            response.put('records', caseDetails);
            response.put('fieldLabels', fieldLabels);
            response.put('columns', fieldLabels.keySet());
            response.put('fieldMetadata', fieldMetadata); 
            return response;
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack ' + e.getStackTraceString());
            response.put('error', e.getMessage());
            return response;
        }
    }

    private static List<Case> getCaseRecord(List<String> recordIdList) {
        initializeFieldSet(); 
        String query = 'SELECT ' + fieldList  +  ' FROM Case WHERE Id IN :recordIdList';
        return Database.query(query);
    }

    @AuraEnabled
    public static String mergeCases(String caseRecordIds, Map<String, Object> selectedFields, String masterCaseIdentifer, String columnIndex) {
        try {
            initializeFieldSet(); 
            List<String> caseIds =  (List<String>) JSON.deserialize(caseRecordIds, List<String>.class);
            String query =  'SELECT ' + fieldList  + ' FROM Case WHERE Id IN :caseIds'; 

            List<Case> cases = Database.query(query);

            Case case1 = cases[0];
            Case case2 = cases[1];
            List<Case> casesToUpdate = new List<Case>();

            Case primaryCase = String.isNotBlank(masterCaseIdentifer) && masterCaseIdentifer == case1.Id ? case1 : case2;
            Case secondaryCase = (primaryCase == case1) ? case2 : case1;
            System.debug('Case IDs' + primaryCase.Type + secondaryCase.Type);
                        
            for (String fieldName : selectedFields.keySet()) {
                 String selectedCaseIndex = (String) selectedFields.get(fieldName);
                 if(selectedCaseIndex != columnIndex ){
                    if (fieldName.contains('.')) {
                        List<String> splitFieldNameParts = fieldName.split('\\.');
                        if (splitFieldNameParts.size() == 2) {
                             if (splitFieldNameParts[0].endsWith('__r')) {
                                String relationshipField = splitFieldNameParts[0].replace('__r', '__c');
                                String relatedField = splitFieldNameParts[1];
                                Id primaryRelatedId = (Id) primaryCase.get(relationshipField);
                                Id secondaryRelatedId = (Id) secondaryCase.get(relationshipField);
                                if (primaryRelatedId == null || !primaryRelatedId.equals(secondaryRelatedId)) {
                                    primaryCase.put(relationshipField, secondaryRelatedId);
                                }
                            }else{
                                String relatedObject = splitFieldNameParts[0]; 
                                String lookupField = relatedObject + 'Id';  
                                // Id selectedValue = (columnIndex == '1') ? (Id) secondaryCase.get(lookupField) : (Id) primaryCase.get(lookupField);
                                Id selectedValue = (Id) secondaryCase.get(lookupField);
                                if ((primaryCase.get(lookupField) == null) || !primaryCase.get(lookupField).equals(selectedValue)) {
                                    primaryCase.put(lookupField, selectedValue);
                                }
                            }
                        }
                    }else if( primaryCase.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName) ) {
                        Object primaryValue = primaryCase.get(fieldName);
                        // Object secondaryValue = (selectedCaseIndex == '1') ? secondaryCase.get(fieldName) : primaryValue;
                        Object secondaryValue = secondaryCase.get(fieldName);
                        System.debug('inside mergeCase' + primaryValue + 'secon' + secondaryValue);
                        if (primaryValue == null || !primaryValue.equals(secondaryValue)) {
                            primaryCase.put(fieldName, secondaryValue); 
                        }
                    }
                 }
            }
            primaryCase.Case_Locked__c = true;
            primaryCase.OwnerId = UserInfo.getUserId();
            System.debug('Check primaryCase' + primaryCase );
            secondaryCase.Status = 'Merged';
            casesToUpdate.add(secondaryCase);
            
            if (String.isBlank((String) primaryCase.get('Type'))) {
                primaryCase.put('Type', 'All Other');
                primaryCase.put('All_Other_Reason__c', 'Merged Case');
            }
            casesToUpdate.add(primaryCase);
            update casesToUpdate;

            return 'Success';
        } catch (Exception e) {
             System.debug('Exception' + e.getMessage());
             throw new AuraHandledException('Error merging cases: ' + e.getMessage());
        }
    }

    public static void initializeFieldSet() {
        if (!fieldSet.isEmpty()) return;
        
        Schema.DescribeSObjectResult caseDescribe = Schema.SObjectType.Case;
        Map<String, Schema.SObjectField> fieldMap = caseDescribe.fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            String fieldApiName = fieldDescribe.getName();
            
            if(fieldDescribe.getType() == Schema.DisplayType.DATE || fieldDescribe.getType() == Schema.DisplayType.DATETIME ){
				dateRelatedFields.add(fieldApiName);
            }
            
			if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
                if (!fieldSet.contains(fieldApiName)) {
                    fieldSet.add(fieldApiName);
                    fieldLabels.put(fieldApiName, fieldDescribe.getLabel());
                    fieldMetadata.put(fieldApiName, fieldDescribe.isUpdateable() ? 'true' : 'false');
                }
            }
            else if (fieldApiName != 'MasterRecordId' && fieldApiName != 'ParentId' && fieldApiName != 'AssetWarrantyId') {
                if (fieldApiName.endsWith('__c')) {
                    String fieldWithoutC = fieldApiName.substring(0, fieldApiName.length() - 3);
                    String relatedField = fieldWithoutC + '__r.Name';
                    String label = fieldWithoutC.substring(0, 1).toUpperCase() + fieldWithoutC.substring(1) + ' Name';
                    if (!fieldSet.contains(relatedField)) {
                        fieldSet.add(relatedField);
                        fieldLabels.put(relatedField, label);
                        fieldMetadata.put(relatedField, fieldDescribe.isUpdateable() ? 'true' : 'false');
                    }
                } else if (fieldApiName.endsWith('Id')) {
                    String fieldWithoutId = fieldApiName.substring(0, fieldApiName.length() - 2);
                    String relatedField = fieldWithoutId + '.Name';
                    String label = fieldWithoutId.substring(0, 1).toUpperCase() + fieldWithoutId.substring(1) + ' Name';
                    if (!fieldSet.contains(relatedField)) {
                        fieldSet.add(relatedField);
                        fieldLabels.put(relatedField, label);
                        fieldMetadata.put(relatedField, fieldDescribe.isUpdateable() ? 'true' : 'false');
                    }
                }
            }
        }
        if (!fieldSet.contains('Id')) {
            fieldSet.add('Id');
        }
        fieldList = String.join(fieldSet, ', ');
        System.debug('Final FieldSet: ' + fieldSet);
    }



   public static String isSpecialityTeam(Id userId) {
        try{
            Set<Id> specialtyTeamGroupIds = new Set<Id>();

            /*List<User> usr = [
                SELECT  Id, UserRole.DeveloperName
                FROM User 
                WHERE Id = :userId 
                AND ( UserRole.DeveloperName IN :specialtyTeamRoles OR UserRole.Name IN :specialtyTeamRoleUserRoleName ) ];

            if (usr != null && !usr.isEmpty()){
                return usr[0].UserRole.DeveloperName;
            }*/

            List<User> usrList = [
                SELECT Id, UserRole.DeveloperName, UserRole.Name
                FROM User
                WHERE Id = :userId
            ];

           if (usrList != null && !usrList.isEmpty()) {
                User currentUser = usrList[0];

                if (currentUser.UserRole != null) {
                    String developerName = currentUser.UserRole.DeveloperName;
                    String roleName = currentUser.UserRole.Name;
                    if (specialtyTeamRoles.contains(developerName)) {
                        return developerName; 
                    }
                    for (String roleNameSubStr : specialtyTeamRoleUserRoleName) {
                        if (roleName != null && roleName.contains(roleNameSubStr)) {
                            return developerName; 
                        }
                    }
                }
            }

            List<Group> specialtyGroups = [ SELECT Id, Name FROM Group WHERE Name IN :specialtyTeamNames ];
            for (Group g : specialtyGroups) {
                specialtyTeamGroupIds.add(g.Id);
            }

            List<GroupMember> groupMembers = [ SELECT Group.Name  FROM GroupMember WHERE UserOrGroupId = :userId  AND GroupId IN :specialtyTeamGroupIds ];

            if (!groupMembers.isEmpty()) {
                return groupMembers[0].Group.Name; 
            }

            return 'Non-Specialty';
        }catch(Exception e){
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException('User is not a part of Speciality Team');
        }
    }
    
    /*
        This method checks whether the case is of speciality or not 
    */
    public static Set<String> checkSpecialityTeamCase(Set<Id> setIds){
        try{
            Set<String> caseToReturn = new Set<String>(); 
            List<Case> caseRec = [SELECT Case_Owner_Name__c, Group__c FROM Case WHERE ID IN :setIds];
            
            for(Case c: caseRec){

                if (c.Case_Owner_Name__c != null) {
                    for (String key : caseOwnerMappings.keySet()) {
                        if (c.Case_Owner_Name__c.contains(key)) {
                            String valueToAdd = caseOwnerMappings.get(key) != null ? caseOwnerMappings.get(key) : c.Case_Owner_Name__c;
                            caseToReturn.add(valueToAdd);
                        }
                    }
                }

                if(c.Group__c != null &&
                    (
                        c.Group__c == 'Incident' ||
                        c.Group__c == 'Service' ||
                        c.Group__c == 'Concierge' ||
                        c.Group__c == 'Order Management' ||
                        c.Group__c == 'Pellet' ||
                        c.Group__c == 'Resolution' ||
                        c.Group__c == 'Social and Reviews' ||
                        c.Group__c == 'June Oven' ||
                        c.Group__c == 'Connected Technology Specialists' ||
                        c.Group__c == 'InTouchCX Escalation' ||
                        c.Group__c == 'NPD Contacts'
                    )
                ){
                    caseToReturn.add(c.Group__c);
                }
            }
            return caseToReturn;
        }catch(Exception e){
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException('Something went wrong. Please try again later.');
        }
    }
}