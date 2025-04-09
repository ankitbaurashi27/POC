/**
* @File Name : InscipherTaxFillingImportBatch.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : January 31, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 31, 2025 |   | Initial Version
**/

public class InscipherTaxFillingImportBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Schedulable {
	
	private String batchId;
    private static String INSURANCEPOLICY_SOBJECT_NAME = 'InsurancePolicy';
	private static String ENDORSEMENT_SOBJECT_NAME = 'Endorsement__c';
 
    public InscipherTaxFillingImportBatch(String batchId) {
        this.batchId = batchId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
		// false positive : query to ensure batch execution
        return Database.getQueryLocator('SELECT Id FROM InsurancePolicy LIMIT 1');
    }

	public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try{
    		List<sObject> listOfSobjectToUpdate = new List<sObject>();
            BatchResponseWrapper response = getImportStatusAPI(this.batchId);
            listOfSobjectToUpdate = processTransactionData(response.transactions, this.batchId);
    
            if (!listOfSobjectToUpdate.isEmpty()) {
				processUpdateResponse(Database.update(listOfSobjectToUpdate, false));
            }   
        }catch(Exception ex){
            system.debug('Stack ==> '+ ex.getStackTraceString() +' Message ==> '+ ex.getMessage());
        }
	}
    
	public void finish(Database.BatchableContext context) {}

	public void execute(SchedulableContext sc) {	
		
		Set<String> batchIdSet = new Set<String>();
		for(InsurancePolicy insPolicyRecord : Database.query(getQueryString(INSURANCEPOLICY_SOBJECT_NAME))){
			batchIdSet.add(insPolicyRecord.Inscipher_Batch_Id__c);
		}

		for(Endorsement__c endorsementRecord : Database.query(getQueryString(ENDORSEMENT_SOBJECT_NAME))){
			batchIdSet.add(endorsementRecord.Inscipher_Batch_Id__c);
		}

		for(String batchId : batchIdSet){
			Database.executeBatch(new InscipherTaxFillingImportBatch(batchId), 1);
		}
    }
    
    private static String getQueryString(String sObjectName){
        String whereClause =  'WHERE Filing_Status__c = \'processing\' AND Submitted_to_Inscipher__c = true AND Inscipher_Batch_Id__c != null LIMIT 10000';
        
        return sObjectName == INSURANCEPOLICY_SOBJECT_NAME ?
											   'SELECT Id, Filing_Status__c, Inscipher_Batch_Id__c FROM InsurancePolicy ' +
                            				    whereClause
											  : 'SELECT Id, Filing_Status__c, Inscipher_Batch_Id__c FROM Endorsement__c ' + 
											  	whereClause ; 
    }

	private BatchResponseWrapper getImportStatusAPI(String batchId) {
        HttpResponse response;
		try {
			Http http = new Http();
			HttpRequest request = new HttpRequest();
			request.setEndpoint('https://surpluslines.inscipher.com/api/v4/transaction-import-results.json?apikey=' 
								+ System.Label.Incipher_Auth_Key 
								+ '&batch_id=' + batchId);
			request.setMethod('GET');
			request.setHeader('Content-Type', 'application/json');
			request.setHeader('apiKey', System.Label.Incipher_Auth_Key);

			response = http.send(request);

			if (response.getStatusCode() == 200) {
				System.debug('Response in success : ' + response.getBody());
				return (BatchResponseWrapper) JSON.deserialize(response.getBody(), BatchResponseWrapper.class);
            } else {
                System.debug('Response in error : ' + response.getBody());
				System.debug('API call failed for Batch ID ' + batchId + ': ' + response.getStatus());
				return new BatchResponseWrapper();
			}
		} catch (Exception e) {
			System.debug('Error calling API for Batch ID ' + batchId + ': ' + e.getMessage());
			return new BatchResponseWrapper();
		}
	}

	private List<SObject> processTransactionData(List<TransactionData> transactions, String batchId) {
		List<SObject> updatedRecords = new List<SObject>();
        
		for (TransactionData transactionData : transactions) {
            String objectName = Id.valueOf(transactionData.id)?.getSObjectType()?.getDescribe()?.getName();
            SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            SObject objToUpdate = objType.newSObject(transactionData.id);
			objToUpdate.put('Id', transactionData.id);
			objToUpdate.put('Filing_Status__c', transactionData.status_message);
			objToUpdate.put('Submitted_to_Inscipher__c', transactionData.status_message.contains('Error:') ? false : true);
			objToUpdate.put('Inscipher_Batch_Id__c', transactionData.status_message.contains('Error:') ? null : batchId);
        	updatedRecords.add(objToUpdate);
		}
		return updatedRecords;
	}

    private void processUpdateResponse(Database.SaveResult[] srList) {
        List<Inscipher_Tax_Filling_Log__c> inscipherLogs = new List<Inscipher_Tax_Filling_Log__c>();

        for (Database.SaveResult sr : srList) {
            if (sr.getErrors() != null && !sr.getErrors().isEmpty()) {
                Database.Error err = sr.getErrors()[0];
                String sObjName = sr.getId().getSObjectType().getDescribe().getName();
                
                if(sObjName == INSURANCEPOLICY_SOBJECT_NAME){
                    inscipherLogs.add(new Inscipher_Tax_Filling_Log__c(
                        Insurance_Policy__c = sr.getId(), 
                        Type__c = 'Import Status API',
                        Error__c = err.getMessage() + ' ' + err.getFields()
                    ));
                }

                if(sObjName == ENDORSEMENT_SOBJECT_NAME){
                    inscipherLogs.add(new Inscipher_Tax_Filling_Log__c(
                        Endorsement__c = sr.getId(), 
                        Type__c = 'Import Status API',
                        Error__c = err.getMessage() + ' ' + err.getFields()
                    ));
                }
            }
        }

        if(!inscipherLogs.isEmpty()){
            insert inscipherLogs;
        }
    }


	public class BatchResponseWrapper {
        public String batch_id;
        public String status;
        public List<TransactionData> transactions;
    }     

    public class TransactionData {
        public String id;
        public String policy_number;
        public Integer transaction_id;
        public Integer status;
        public String status_message;
        public Warnings warnings;
    }

    public class Warnings {
        public String lineOfBusiness;
        public String total;
        public String slTax;
        public String stampingFee;
    }
}