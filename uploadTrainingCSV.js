import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadCSV from '@salesforce/apex/CSVUploadController.uploadCSV';

export default class UploadTrainingCSV extends LightningElement {
    @track csvFile;
    @track errorMessage;
    @track successMessage;
    @track isLoading = false;
    @api recordId;

    handleFileChange(event) {
        const file = event.target.files[0];
        const reader = new FileReader();

        reader.onload = () => {
            this.csvFile = reader.result;
            this.errorMessage = null;
            console.log('File content:', this.csvFile); // Debugging line
        };

        reader.onerror = () => {
            this.errorMessage = 'Error reading file';
            console.error('Error reading file'); // Debugging line
        };

        if (file) {
            reader.readAsText(file);
        }
    }

    handleUpload() {
        if (!this.csvFile) {
            this.errorMessage = 'Please select a CSV file to upload.';
            this.successMessage = null;
            return;
        }

        this.isLoading = true;
        this.errorMessage = null;
        this.successMessage = null;

        uploadCSV({ csvContent: this.csvFile, accountId: this.recordId })
            .then(() => {
                this.successMessage = 'CSV file uploaded successfully';
                this.errorMessage = null;
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'CSV file uploaded successfully',
                        variant: 'success',
                    })
                );
                console.log('Upload successful'); // Debugging line
            })
            .catch(error => {
                this.errorMessage = 'Error uploading CSV file: ' + error.body.message;
                this.successMessage = null;
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Error uploading CSV file: ' + error.body.message,
                        variant: 'error',
                    })
                );
                console.error('Upload error:', error.body.message); // Debugging line
            });
    }
}
