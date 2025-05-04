
from ics import Calendar, Event
from ics.grammar.parse import ContentLine
import re
import dateparser


GERMAN_TIME_ORDINALS = {
    'Ein': '01', 'Eins': '01', 'Zwei': '02', 'Drei': '03', 'Vier': '04', 'Fünf': '05', 'Sechs': '06', 'Sieben': '07', 'Acht': '08',
    'Neun': '09', 'Zehn': '10', 'Elf': '11', 'Zwölf': '12', 'Dreizehn': '13', 'Vierzehn': '14', 'Fünfzehn': '15',
    'Sechzehn': '16', 'Siebzehn': '17', 'Achterzehn': '18', 'Neunzehn': '19', 'Zwanzig': '20', 'Einundzwanzig': '21', 'Zweiundzwanzig': '22',
    'Dreiundzwanzig': '23', 'Vierundzwanzig': '24', 'Fünfundzwanzig': '25', 'Sechsundzwanzig': '26', 'Siebundzwanzig': '27',
    'Achtundzwanzig': '28', 'Neunundzwanzig': '29', 'Dreißig': '30', 'Einunddreißig': '31', 'Zweiunterdreißig': '32',
    'Dreiunderdreißig': '33', 'Vierunterdreißig': '34', 'Fünfunddreißig': '35', 'Sechsunddreißig': '36', 'Siebunddreißig': '37',
    'Achtunddreißig': '38', 'Neununddreißig': '39', 'Vierzig': '40', 'Einundvierzig': '41', 'Zweiundvierzig': '42',
    'Dreiundvierzig': '43', 'Vierundvierzig': '44', 'Fünfundvierzig': '45', 'Sechsundvierzig': '46', 'Siebundvierzig': '47',
    'Achtundvierzig': '48', 'Neunundvierzig': '49', 'Fünfzig': '50', 'Einundfünfzig': '51', 'Zweiundfünfzig': '52',
    'Dreiundfünfzig': '53', 'Vierundfünfzig': '54', 'Fünfundfünfzig': '55', 'Sechsundfünfzig': '56', 'Siebundfünfzig': '57',
    'Achtundfünfzig': '58', 'Neunundfünfzig': '59', 'Null': '00'
}

GERMAN_DATE_ORDINALS = {
    'erster': '1.', 'zweiter': '2.', 'dritter': '3.', 'vierter': '4.',
    'fünfter': '5.', 'sechster': '6.', 'siebter': '7.', 'achter': '8.',
    'neunter': '9.', 'zehnter': '10.', 'elfter': '11.', 'zwölfter': '12.',
    'dreizehnter': '13.', 'vierzehnter': '14.', 'fünfzehnter': '15.',
    'sechzehnter': '16.', 'siebzehnter': '17.', 'achtzehnter': '18.',
    'neunzehnter': '19.', 'zwanzigster': '20.', 'einundzwanzigster': '21.',
    'zweiundzwanzigster': '22.', 'dreiundzwanzigster': '23.',
    'vierundzwanzigster': '24.', 'fünfundzwanzigster': '25.',
    'sechsundzwanzigster': '26.', 'siebundzwanzigster': '27.',
    'achtundzwanzigster': '28.', 'neunundzwanzigster': '29.',
    'dreißigster': '30.', 'einunddreißigster': '31.'
}

GERMAN_WEEKDAYS = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag']

GERMAN_MONTHS = {
    '01': 'Januar', '02': 'Februar', '03': 'März', '04': 'April', '05': 'Mai', '06': 'Juni', '07': 'Juli', '08': 'August',
    '09': 'September', '10': 'Oktober', '11': 'November', '12': 'Dezember'
}


### Time Normalizer ------------------------------------------------

def normalize_ordinal_times(text):
    for word, number in GERMAN_TIME_ORDINALS.items():
        pattern = rf'\b{word}\b'
        text = re.sub(pattern, number, text, flags=re.IGNORECASE)
    return text

def normalize_time_expressions(text):

    # oO -> 0
    text = re.sub(r'[oO]', '0', text)
    # 00 : 11 -> 00:11
    text = re.sub(r'(\d)\s*[:.]\s*(\d)', r'\1:\2', text)
    # 06 Uhr 16 -> 0616
    text = re.sub(r'(\d{2}) Uhr (\d{2})', r'\1\2', text)
    # Uhr entfernen
    text = re.sub(r'\s*\bUhr\b', r'', text, flags=re.IGNORECASE)
    #16 -> 16:00, 6 -> 06:00
    text = re.sub(r'\b(?<!:|.)(\d{1,2})\b(?!(:|.)\d{2})', r'\1:00', text)
    #16 00 -> 1600
    text = re.sub(r'(\d{1,2})\s*(\d{2})\b', r'\1\2', text)
    #1600 -> 16:00
    text = re.sub(r'(\b\d{1,2})(\d{2}\b)', r'\1:\2', text)

    #Ganztägig -> 00:11
    text = re.sub(r'Ganztägig', '00:11', text, flags=re.IGNORECASE)
    text = re.sub(r'Ganztags', '00:11', text, flags=re.IGNORECASE)
    text = re.sub(r'(am )?(de[nrm]? )?ganze[nr]? Tag', '00:11', text, flags=re.IGNORECASE)

    return text


def time_normalizer(text):
  text = normalize_ordinal_times(text)
  text = normalize_time_expressions(text)
  return text


### Date Normalizer ------------------------------------------------

def normalize_ordinal_dates(text):
  for word, number in GERMAN_DATE_ORDINALS.items():
    pattern = rf'\b{word}\b'
    text = re.sub(pattern, number, text, flags=re.IGNORECASE)
  return text

def normalize_date_expressions(text):

  wiederholend = False  #Wchtl. Wiederholung (Alt.: wiederholend = False, interavll = wchtl/mntl/tägl, anzahl = 5)

  #4.o8.2O25 -> 4.08.2025
  text = re.sub(r'(\d)[oO]', r'\g<1>0', text)
  text = re.sub(r'[oO](\d)', r'0\g<1>', text)
  #06.03. -> 06.3.
  text = re.sub(r'\.0(\d)', r'.\g<1>', text)

  #12.12. - > 12. Dezember
  for number, word in GERMAN_MONTHS.items():
    pattern = rf'(\b\d{{1,2}})\.{number}\.?'
    text = re.sub(pattern, rf'\1. {word} ', text)

  #Nächster Montag -> Montag
  text = re.sub(r'\bnächster\b\s*',r'', text, flags=re.IGNORECASE)

  #Am Montag -> Montag
  text = re.sub(r'\bam\b\s*',r'', text, flags=re.IGNORECASE)

  #Freitag (der) 05. April -> 05. April
  for word in GERMAN_WEEKDAYS:
    text = re.sub(rf'\b{word}\b\s*der\s*(\d)', r'\1', text, flags=re.IGNORECASE)
    text = re.sub(rf'\b{word}\b\s*(\d)', r'\1', text, flags=re.IGNORECASE)

    #Montags -> Montag (W)
    found_match = re.search(rf'\b{word}s\b', text, flags=re.IGNORECASE)
    if found_match:
      wiederholend = True
      text = re.sub(rf'\b{word}s\b', rf'{word}', text, flags=re.IGNORECASE)

  #Jeden/Jeder Montag -> Montag (W)
  found_match = re.search(r'Jede.', text, flags=re.IGNORECASE)
  if found_match:
    wiederholend = True
    text = re.sub(r'\bJede.\b\s*', '', text)
  
  #Wochenende -> Samstag    (Alt.: intervall = tägl, anzahl = 3)
  text = re.sub(r'\bWochenende\b',r'Samstag', text, flags=re.IGNORECASE)
  text = re.sub(r'\WE\b',r'Samstag', text, flags=re.IGNORECASE)

  return text, wiederholend

def date_normalizer(text):
  text = normalize_ordinal_dates(text)
  text, wiederholend = normalize_date_expressions(text)
  return text, wiederholend


### Prepare ics data ------------------------------------------------

def prepare_ics_name(name_tokens):
  ics_name = ''
  for token in name_tokens:
    ics_name += token + '|'
  return ics_name[:-1]

def prepare_ics_description(link_tokens):
  ics_description = ''
  for token in link_tokens:
    token_no_spaces = token.replace(' ', '')
    ics_description += token_no_spaces + '|'
  return ics_description[:-1]

def prepare_ics_location(location_tokens):
  ics_location = ''
  for token in location_tokens:
    ics_location += token + ' '
  return ics_location[:-1]

def prepare_ics_datetime(date_tokens, time_tokens):
  ics_datetime = ''
  repeats = False

  if(time_tokens == []):
    time_tokens = ["00:11"]   #Default, Code für Ganztägig
  if(date_tokens == []):
    date_tokens = ["Heute"]   #Default

  
  date = ''
  for token in date_tokens:
    date += token + ' '
  date = date[:-1]
  norm_date, repeats = date_normalizer(date)

  time = ''
  for token in time_tokens:
    time += token + ' '
  time = time[:-1]
  norm_time = time_normalizer(time)
  try:
    datetime = norm_date + ' ' + norm_time
    ics_datetime = dateparser.parse(datetime, settings={'PREFER_DATES_FROM': 'future',"PREFER_MONTH_OF_YEAR": "current"}, languages=['de']).strftime("%Y-%m-%d %H:%M:%S") #YYYY-MM-DD HH:mm:ss
  except:
    try: 
      datetime = norm_date + ' 00:11' #Default, Code für Ganztägig
      ics_datetime = dateparser.parse(datetime, settings={'PREFER_DATES_FROM': 'future',"PREFER_MONTH_OF_YEAR": "current"}, languages=['de']).strftime("%Y-%m-%d %H:%M:%S") #YYYY-MM-DD HH:mm:ss
    except:
      try: 
        datetime = 'Heute ' + norm_time #Default
        ics_datetime = dateparser.parse(datetime, settings={'PREFER_DATES_FROM': 'future',"PREFER_MONTH_OF_YEAR": "current"}, languages=['de']).strftime("%Y-%m-%d %H:%M:%S") #YYYY-MM-DD HH:mm:ss
      except:
        datetime = 'Heute 00:11' #Default
        ics_datetime = dateparser.parse(datetime, settings={'PREFER_DATES_FROM': 'future',"PREFER_MONTH_OF_YEAR": "current"}, languages=['de']).strftime("%Y-%m-%d %H:%M:%S") #YYYY-MM-DD HH:mm:ss
  
  return ics_datetime, repeats

def prepare_ics_duration(duration_tokens):      #Unvollständig <-----------
  if(duration_tokens == []):
    return 1
  return duration_tokens[0]


### Create ics ------------------------------------------------

def create_ics(name_tokens, date_tokens, time_tokens, location_tokens, duration_tokens, link_tokens):
  ics_name = prepare_ics_name(name_tokens)
  ics_description = prepare_ics_description(link_tokens)
  ics_location = prepare_ics_location(location_tokens)
  ics_datetime, repeats = prepare_ics_datetime(date_tokens, time_tokens)
  ics_duration = prepare_ics_duration(duration_tokens)

  c = Calendar()
  e = Event()
  e.name = ics_name
  e.begin = ics_datetime
  #e.end = ics_datetime + 'T' + ics_duration + ':00'  #Noch Pseudo-Code
  #e.duration = (ics_duration + ':00')
  e.description = ics_description
  e.location = ics_location

  found_match = re.search(r'00:11', ics_datetime, flags=re.IGNORECASE)  #Abfrage nach Code 00:11
  if(found_match):
    e.make_all_day() 

  if(repeats):
    e.extra.append(
      ContentLine(name="RRULE", value="FREQ=WEEKLY;COUNT=4")    #Default = 4? oder Infinite?
    )

  c.events.add(e)

  return c.serialize()