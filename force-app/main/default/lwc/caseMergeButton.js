import { LightningElement, api, track } from 'lwc';
import getRecords from '@salesforce/apex/CaseMergeHandler.getSelectedRecords';
import mergeCases from '@salesforce/apex/CaseMergeHandler.mergeCases';

export default class CaseMergeButton extends LightningElement {
    
    @track columns = [];
    @track fieldData = {};
    @track error;
    @api caseRecordIds = [];
    @track showTable = false;
    @track selectedFields = {};
    @track modalTitle = 'Error';
    @track modalMessage = '';
    @track isModalOpen = false;
    @track hideNext = false;
    @track isLoading = false;
    @track excludedFields = ['Id', 'RecordTypeId', 'CreatedById', 'LastModifiedById', 'SystemModstamp', 'LastViewedDate', 'OwnerId', 'IsDeleted'];
    @track checked = false;
    @track showAllFields = false; 
    @track displayFields = [];  
    @track useAsPrincipal;
    @track isMerge = false; 
    @track firstCheckBox = false;
    @track secondCheckBox = false;
    @track firstVal;
    @track secondVal;
    @track isSuccess = false;
    @track isError = true;
    

    connectedCallback() {
        if (this.caseRecordIds && this.caseRecordIds.length > 0) {
            this.firstVal = this.caseRecordIds[0];
            console.log('First Record ID:', this.firstVal);
            this.secondVal = this.caseRecordIds[1];
            console.log('secondVal Record ID:', this.secondVal);
        } else {
            console.log('caseRecordIds is empty or not available');
        }

        this.isLoading = true;
        this.fetchRecords();
        this.isLoading = false;
    }

    openModal(title, message) {
        this.modalTitle = title;
        this.modalMessage = message;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        if(!this.isMerge || this.isSuccess){
            window.history.back();
        }
    }

    async fetchRecords() {
        this.isLoading = true;
        try {
            const response = await getRecords({ recordIds: JSON.stringify(this.caseRecordIds) });
            if(response.error && response.error != undefined){
                this.showTable = false;
                this.openModal('Error', response.error);
                return;
            }
            this.records = response.records;
            const fieldLabels = response.fieldLabels;
            const allColumns = Array.from(response.columns || []);
            const fieldMetadata = response.fieldMetadata;
            console.log('records' , JSON.stringify(this.records));
            this.prepareFieldData(this.records, allColumns, fieldLabels, fieldMetadata);
        } catch (error) {
            this.isModalOpen = true;
            this.hideNext = true;
            this.openModal('Error', error.body.message);
        } finally {
            this.isLoading = false;
        }
    }

    prepareFieldData(records, columns, fieldLabels, fieldMetadata) {
        if (!records || records.length === 0) return;

        const filteredColumns = columns.filter(fieldName => {
            return !this.excludedFields.includes(fieldName) &&
                records.some(record => record[fieldName] != null && record[fieldName] !== '');
        });

        // Initialize an empty Set to track already processed fields
        const processedFields = new Set();

        this.fieldData = filteredColumns.map(fieldName => {
            const values = records.map(record => {
                const value = record[fieldName];
                return value === null || value === undefined || value === '' ? '[empty]' : value;
            });

            const isAllValuesSame = values.every(value => value === values[0]);
            const fieldMetadataValue = fieldMetadata[fieldName] === "true";

            // Mark field as processed
            processedFields.add(fieldName);

            return {
                fieldLabel: fieldLabels[fieldName] || fieldName,
                fieldName: fieldName,
                isEditable: fieldMetadataValue && !isAllValuesSame,
                values: values
            };
        });

        // Process related fields only if not already processed
        const relatedFields = filteredColumns.filter(field => field.includes('.'));
        relatedFields.forEach(field => {
            if (!processedFields.has(field)) {
                const values = records.map(record => record[field] || '[empty]');
                const allValuesAreSame = values.every(value => value === values[0]);
                const fieldMetadataValue = fieldMetadata[field] === "true";

                if (values.some(value => value !== '[empty]')) {
                    this.fieldData.push({
                        fieldLabel: fieldLabels[field] || field.replace(/([A-Z])/g, ' $1').trim(),
                        fieldName: field,
                        isEditable: fieldMetadataValue && !allValuesAreSame,
                        values: values
                    });
                }

                // Mark related field as processed
                processedFields.add(field);
            }
        });

        console.log('Related Fields ', JSON.stringify(this.fieldData));
        this.displayFields = this.fieldData;
        this.showTable = true; 
    }

    toggleShowFields() {
        this.showAllFields = !this.showAllFields;
        //this.displayFields = this.showAllFields ? this.fieldData : this.fieldData.slice(0, 15);
        this.displayFields = this.fieldData;
        //this.displayFields.push(this.fieldData);
    }

    columnIndx;

    handleFieldSelection(event) {
        const fieldName = event.target.dataset.field;
        const selectedIndex = event.target.dataset.index;
        this.selectedFields[fieldName] = undefined;
        this.selectedFields[fieldName] = selectedIndex;
        console.log('eww', JSON.stringify(this.selectedFields));
    }

    handleSelectAll(event){
        try {
            const columnIndex = Number(event.target.dataset.column);
            this.checked = event.target.checked;
            this.displayFields.forEach(field => {
            const valueAtIndex = field.values[columnIndex];
            field.checked = true;
            if (valueAtIndex !== undefined) {
                this.selectedFields[field.fieldName] = this.checked ? valueAtIndex : null;
            }
            });
            console.log('Updated selectedFields:', JSON.stringify(this.selectedFields));
        } catch (error) {
            console.error('Error occurred while updating selected fields:', error);
        }
    }

    handleUseasPrincipal(event){
        const selectedId = event.target.dataset.rec;
        this.columnIndx = selectedId;
        if(selectedId === '1'){
            this.useAsPrincipal = event.target.dataset.val;
            this.secondCheckBox = true;
            this.firstCheckBox = false;
        }else{
            this.useAsPrincipal = event.target.dataset.val;
            this.secondCheckBox = false;
            this.firstCheckBox = true;
        }
    }

    handleNext(event) {
        this.isLoading = true;
        this.isMerge = true;
        console.log("Merge records or proceed.");

        if (!this.selectedFields || !this.useAsPrincipal) {
            this.isLoading = false; 
            this.openModal('Error', 'Please select fields and a principal case to merge.');
            return; 
        }

        mergeCases({
            caseRecordIds: JSON.stringify(this.caseRecordIds),
            selectedFields: this.selectedFields,
            masterCaseIdentifer: this.useAsPrincipal,
            columnIndex: this.columnIndx
        })
        .then((result) => {
            console.log('Cases merged successfully!', result);
            this.isLoading = false;

            if (result !== 'Success') {
                this.isModalOpen = true;
                this.isError = true;
                this.selectedFields = {};
                this.openModal('Error', result);
            } else {
                this.isModalOpen = true;
                this.isSuccess = true;
                this.openModal('Success', 'Cases Merged Successfully!!');
            }
        })
        .catch(error => {
            this.isLoading = false;
            this.selectedFields = {};
            this.openModal('Error', error.body.message);
        });
    }

    /*showToast(message, title, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        setTimeout(() => {
            this.dispatchEvent(evt);
        }, 100);
    }*/
}