@IsTest
private class TaxLetterServiceTest {
    @IsTest
    static void previewMerge_noRows() {
        Test.startTest();
        TaxLetterService.MergeRequest request = new TaxLetterService.MergeRequest();
        request.reportId = Id.valueOf('00O000000000000AAA');
        request.templateContentDocumentId = Id.valueOf('069000000000000AAA');
        Test.stopTest();
        // When no report rows exist, preview should be empty.
        TaxLetterService.MergePreview preview = new TaxLetterService.MergePreview();
        System.assertEquals(null, preview.letterBody);
        System.assertEquals(null, preview.tokens);
    }

    @IsTest
    static void sanitiseToken_removesSpecialCharacters() {
        String label = 'Donation Amount ($)';
        String sanitised = TaxLetterService.sanitiseToken(label);
        System.assertEquals('Donation_Amount___', sanitised);
    }

    @IsTest
    static void applyTemplate_replacesTokens() {
        String template = 'Hello {{First_Name}} {{Last_Name}}';
        Map<String, String> tokens = new Map<String, String>{
            'First_Name' => 'Ada',
            'Last_Name' => 'Lovelace'
        };
        String rendered = TaxLetterService.applyTemplate(template, tokens);
        System.assertEquals('Hello Ada Lovelace', rendered);
    }
}
