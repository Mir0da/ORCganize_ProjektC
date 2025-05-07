from transformers import pipeline
from transformers import AutoTokenizer
from transformers import AutoModelForTokenClassification

tokenizer = AutoTokenizer.from_pretrained("MissAvery/distilbert-german-finetuned-ner-v1")
model = AutoModelForTokenClassification.from_pretrained("MissAvery/distilbert-german-finetuned-ner-v1")
token_classifier = pipeline("token-classification", model=model, tokenizer=tokenizer, aggregation_strategy="simple")


def extract_tokens(sentence: str):
  tokens = token_classifier(sentence)

  name_tokens = []
  date_tokens = []
  time_tokens = []
  location_tokens = []
  duration_tokens = []
  link_tokens = []
  for token in tokens:
    match token.get('entity_group'):
      case 'TYP':
        name_tokens.append(token.get('word'))
      case 'DAT':
        date_tokens.append(token.get('word'))
      case 'TIM':
        time_tokens.append(token.get('word'))
      case 'LOC':
        location_tokens.append(token.get('word'))
      case 'DUR':
        duration_tokens.append(token.get('word'))
      case 'URL':
        link_tokens.append(token.get('word'))

  return name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens