public class BrieflyDocumentationGenerator {

    // The method should be invocable so it can be called from a Flow or Action
    @InvocableMethod(label='Generate Project Documentation' description='Generates a Project Documentation and sends it via HTTP POST to a third party service.')
    public static List<DocumentationResult> generateDocumentation(List<Id> projectIds) {
        List<DocumentationResult> results = new List<DocumentationResult>();

        for (Id projectId : projectIds) {
            // Fetch the project data along with its associated Epics and Stories
            Project__c project = [SELECT Name, Description__c, Objectives__c, 
                                  	SuccessIndicators__c, Deliverables__c, 
                                  DocumentationLink__c, 
                                  (SELECT Name FROM Epics__r) 
                                  FROM Project__c WHERE Id = :projectId LIMIT 1];

            // Prepare the JSON payload
            String jsonPayload = prepareJsonPayload(project);
            
            // Send the HTTP POST request to the provided URL
            String response = sendHttpPostRequest(jsonPayload);
            
            // Parse the response to extract the link URL
            String linkUrl = parseResponseForLink(response);
            
            if (linkUrl != null) {
                // Update the Project record with the returned link URL
                project.DocumentationLink__c = linkUrl;
                update project;  // Update the Documentation__c field
            }
            
            // Construct a result object to return
            DocumentationResult result = new DocumentationResult();
            result.projectId = projectId;
            result.response = response;
            result.linkUrl = linkUrl;
            results.add(result);
        }

        return results;
    }

    // Method to prepare the JSON payload
    private static String prepareJsonPayload(Project__c project) {
        // Fetch epic and story data
        List<Epic__c> epics = [SELECT Name, (SELECT Name, Description__c, Story_Size__c FROM Stories__r) 
                               FROM Epic__c WHERE Project__c = :project.Id];

        // Build the UserStories HTML content
        String userStoriesHtml = '';
        for (Epic__c epic : epics) {
            userStoriesHtml += '<p class="c23"><span class="c24">' + epic.Name + ' Stories</span></p>';
            userStoriesHtml += '<table border="1"><thead><tr><th>Story Name</th><th>Story Description</th><th>Estimated Story Size</th></tr></thead><tbody>';
            
            for (Story__c story : epic.Stories__r) {
                userStoriesHtml += '<tr>';
                userStoriesHtml += '<td>' + story.Name + '</td>';
                userStoriesHtml += '<td>' + story.Description__c + '</td>';
                userStoriesHtml += '<td>' + story.Story_Size__c + '</td>';
                userStoriesHtml += '</tr>';
            }
            
            userStoriesHtml += '</tbody></table><br/>';
        }

 
    // Prepare the JSON payload using proper escaping for special characters
    String jsonPayload = '{' +
                         '"ProjectName":"' + escapeJsonString(project.Name) + '",' +
                         '"CreatedDate":"' + System.today().format() + '",' +
                         '"Owner":"' + escapeJsonString(UserInfo.getName()) + '",' +
                         '"ProjectDescription":"' + escapeJsonString(project.Description__c) + '",' +
                         '"Goals":"' + escapeJsonString(project.Objectives__c) + '",' +
                         '"SuccessIndicators":"' + escapeJsonString(project.SuccessIndicators__c) + '",' +
                         '"Deliverables":"' + escapeJsonString(project.Deliverables__c) + '",' +
                         '"UserStories":"' + escapeJsonString(userStoriesHtml) + '"' +
                         '}';
        System.debug('Generated JSON Payload: ' + jsonPayload);
        return jsonPayload;
    }

// Helper method to escape double quotes and backslashes in the string
private static String escapeJsonString(String input) {
    if (input == null) {
        return '';
    }
    // Escape double quotes and backslashes
    input = input.replace('\\', '\\\\');  // Escape backslashes first
    input = input.replace('\"', '\\"');    // Escape double quotes
    return input;
}
    
    // Method to send HTTP POST request to document creation
    private static String sendHttpPostRequest(String jsonPayload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://68724eea76a5723aacd44399.mockapi.io/createdoc');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonPayload);
        
        Http http = new Http();
        HttpResponse res = http.send(req);

        // Return the response body
        return res.getBody();
    }

    // Method to parse the response and extract the link URL
    private static String parseResponseForLink(String response) {
        // Parse the response JSON to extract the link
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
            return (String) responseMap.get('link');  // Assuming the link is under the "link" key
        } catch (Exception e) {
            System.debug('Error parsing response: ' + e.getMessage());
            return null;
        }
    }

    // Result wrapper class for returning the response
    public class DocumentationResult {
        @InvocableVariable(label='Project ID' description='The ID of the project for which documentation was generated')
        public Id projectId;

        @InvocableVariable(label='Response' description='The response from the HTTP POST request')
        public String response;

        @InvocableVariable(label='Link URL' description='The URL of the generated documentation')
        public String linkUrl;
    }
}