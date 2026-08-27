// Azure AI (Translator) credentials — DO NOT COMMIT THIS FILE.
// This file is listed in .gitignore. See azure_config.example.dart for the
// template new contributors should copy.

class AzureConfig {
  static const String translatorKey =
      '916BoQlEy4OaoNZeLrYHE2Txqrmia8kbM3Fiqy3m75ZwUxTMHUjUJQQJ99CHACmepeSXJ3w3AAAAACOGejJa';
  static const String translatorRegion = 'uksouth';

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
