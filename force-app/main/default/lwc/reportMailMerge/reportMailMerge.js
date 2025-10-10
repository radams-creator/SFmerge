import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import previewMerge from '@salesforce/apex/TaxLetterService.previewMerge';
import generateLetters from '@salesforce/apex/TaxLetterService.generateLetters';

export default class ReportMailMerge extends LightningElement {
    @track reportId;
    @track templateId;
    @track deliveryOption = 'FILE';
    @track preview;
    isGenerating = false;

    get deliveryOptions() {
        return [
            { label: 'Download Files', value: 'FILE' },
            { label: 'Send Emails', value: 'EMAIL' }
        ];
    }

    renderedCallback() {
        this.renderPreview();
    }

    get isGenerateDisabled() {
        return !this.reportId || !this.templateId || this.isGenerating;
    }

    get tokenEntries() {
        if (!this.preview || !this.preview.tokens) {
            return [];
        }
        return Object.keys(this.preview.tokens).map(key => ({ key, value: this.preview.tokens[key] }));
    }

    handleReportChange(event) {
        this.reportId = event.target.value;
    }

    handleTemplateChange(event) {
        this.templateId = event.target.value;
    }

    handleDeliveryChange(event) {
        this.deliveryOption = event.detail.value;
    }

    async handlePreview() {
        if (!this.reportId || !this.templateId) {
            return;
        }
        try {
            const request = {
                reportId: this.reportId,
                templateContentDocumentId: this.templateId,
                deliveryOption: this.deliveryOption,
                previewOnly: true
            };
            this.preview = await previewMerge({ request });
            this.renderPreview();
        } catch (error) {
            this.showError(error);
        }
    }

    async handleGenerate() {
        if (this.isGenerateDisabled) {
            return;
        }
        this.isGenerating = true;
        try {
            const request = {
                reportId: this.reportId,
                templateContentDocumentId: this.templateId,
                deliveryOption: this.deliveryOption,
                previewOnly: false
            };
            const ids = await generateLetters({ request });
            this.dispatchEvent(new CustomEvent('lettersgenerated', { detail: ids }));
        } catch (error) {
            this.showError(error);
        } finally {
            this.isGenerating = false;
        }
    }

    renderPreview() {
        const container = this.template.querySelector('.preview-body');
        if (!container || !this.preview) {
            return;
        }
        container.innerHTML = this.preview.letterBody || '';
    }

    showError(error) {
        // eslint-disable-next-line no-console
        console.error('Mail merge error', error);
        let message = 'An unexpected error occurred.';
        if (error) {
            if (error.body && error.body.message) {
                message = error.body.message;
            } else if (error.message) {
                message = error.message;
            }
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Mail Merge Error',
                message,
                variant: 'error'
            })
        );
    }
}
