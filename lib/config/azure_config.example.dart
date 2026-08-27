// Template for lib/config/azure_config.dart — copy this file to
// azure_config.dart (gitignored) and fill in your own Azure Translator
// resource's key + region from the Azure Portal: your resource ->
// "Keys and Endpoint".

class AzureConfig {
  static const String translatorKey = 'YOUR_AZURE_TRANSLATOR_KEY';
  static const String translatorRegion = 'YOUR_AZURE_REGION'; // e.g. uksouth

  // TODO: fill in after creating an Azure OpenAI model deployment in Azure
  // AI Foundry (see lib/services/translation_alternatives_service.dart's
  // normalizeToLemmaForm doc comment for setup steps). These are NOT
  // guaranteed to be the same as translatorKey/translatorRegion above --
  // only reuse translatorKey here if your Foundry resource is confirmed to
  // be a unified multi-service resource with Azure OpenAI enabled on it.
  static const String openAiEndpoint =
      ''; // e.g. https://YOUR-RESOURCE-NAME.openai.azure.com
  static const String openAiDeploymentName = ''; // e.g. gpt-4o-mini
  static const String openAiApiKey = '';
}
