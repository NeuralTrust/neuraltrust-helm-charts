#!/usr/bin/env python3
import json
from clickhouse_driver import Client
import hashlib

def safe_str(value) -> str:
    """
    Return an empty string if the given value is None
    Otherwise, cast to str (in case it's e.g. an int).
    """
    if value is None:
        return ""
    return str(value)

def safe_float(value, default=0.0) -> float:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default

def safe_int(value, default=0) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default

def safe_array_str(value) -> list[str]:
    """
    Ensure we return a list of strings. If it's already a list, cast each item to str.
    If it's a JSON-encoded string, try to parse it back into a list of strings.
    Otherwise, return a single-element list with the stringified value.
    """
    if not value:
        return []
    if isinstance(value, list):
        return [safe_str(item) for item in value]
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [safe_str(item) for item in parsed]
        except:
            pass
        return [value]
    return [safe_str(value)]

def safe_json_string(value) -> str:
    """
    Convert any Python object into a JSON-encoded string. 
    If `value` is already a string, just return it. 
    """
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False)

def main():
    # Adjust these connection parameters to match your ClickHouse setup:
    client = Client(
        host="localhost",
        user="neuraltrust",
        password="", 
        database="neuraltrust"
    )
    
    # Only omit columns that are MATERIALIZED (START_TIME, END_TIME, EVENT_DATE, EVENT_HOUR)
    insert_query = """
    INSERT INTO traces_processed (
        -- Base fields
        APP_ID,
        TEAM_ID,
        TRACE_ID,
        PARENT_ID,
        INTERACTION_ID,
        CONVERSATION_ID,
        SESSION_ID,
        START_TIMESTAMP,
        END_TIMESTAMP,
        LATENCY,
        INPUT,
        OUTPUT,
        FEEDBACK_TAG,
        FEEDBACK_TEXT,
        CHANNEL_ID,
        USER_ID,
        USER_EMAIL,
        USER_PHONE,
        LOCATION,
        LOCALE,
        DEVICE,
        OS,
        BROWSER,
        TASK,
        CUSTOM,

        -- KPI fields
        OUTPUT_CLASSIFIERS,
        TOKENS_SPENT_PROMPT,
        TOKENS_SPENT_RESPONSE,
        READABILITY_RESPONSE,
        NUM_WORDS_PROMPT,
        NUM_WORDS_RESPONSE,
        LANG_PROMPT,
        LANG_RESPONSE,
        MALICIOUS_PROMPT,
        MALICIOUS_PROMPT_SCORE,
        PURPOSE_LABEL,
        SENTIMENT_PROMPT,
        SENTIMENT_PROMPT_POSITIVE,
        SENTIMENT_PROMPT_NEGATIVE,
        SENTIMENT_PROMPT_NEUTRAL,
        SENTIMENT_RESPONSE,
        SENTIMENT_RESPONSE_POSITIVE,
        SENTIMENT_RESPONSE_NEGATIVE,
        SENTIMENT_RESPONSE_NEUTRAL,

        -- PII fields
        PII_PHONE_PROMPT,
        PII_PHONE_RESPONSE,
        PII_CRYPTO_PROMPT,
        PII_CRYPTO_RESPONSE,
        PII_EMAIL_PROMPT,
        PII_EMAIL_RESPONSE,
        PII_CARD_PROMPT,
        PII_CARD_RESPONSE,
        PII_BANK_PROMPT,
        PII_BANK_RESPONSE,
        PII_IP_PROMPT,
        PII_IP_RESPONSE,
        PII_PERSON_PROMPT,
        PII_PERSON_RESPONSE,
        PII_PERSONAL_PROMPT,
        PII_PERSONAL_RESPONSE,
        PII_COMPANY_PROMPT,
        PII_COMPANY_RESPONSE,
        PII_MEDICAL_PROMPT,
        PII_MEDICAL_RESPONSE,
        PII_PASSPORT_PROMPT,
        PII_PASSPORT_RESPONSE,
        PII_DRIVING_PROMPT,
        PII_DRIVING_RESPONSE,
        PII_PROMPT,
        PII_RESPONSE,
        PII_PROMPT_LABEL,
        PII_RESPONSE_LABEL
    ) VALUES
    """
    
    rows = []
    batch_size = 500  # Insert in batches of 500 (or 1000) rows
    
    with open("my_index.json", "r", encoding="utf-8") as json_file:
        for line in json_file:
            line = line.strip()
            if not line:
                continue
            
            doc = json.loads(line)
            source = doc.get("_source", {})
            
            # Map fields as they appear in your schema, with sensible defaults:
            app_id  = '571b9f4b-3f5b-4ff4-84df-06e4b8b22d4e'
            team_id = '0ea3e7bd-41b3-43ba-8f77-4bfeeadde8b7'
            trace_id = hashlib.sha256().hexdigest()
            parent_id = safe_str(source.get("PARENT_ID"))
            interaction_id = safe_str(source.get("INTERACTION_ID", hashlib.sha256().hexdigest()))
            conversation_id = safe_str(source.get("CONVERSATION_ID"))
            session_id = safe_str(source.get("SESSION_ID"))
            
            start_timestamp = source.get("TIMESTAMP", 0)
            end_timestamp   = source.get("TIMESTAMP", 0)
            
            # If you store or compute latency somewhere, load it; otherwise 0
            latency = source.get("LATENCY", 0)
            
            input_text  = safe_str(source.get("INPUT"))
            output_text = safe_str(source.get("OUTPUT"))
            
            feedback_tag  = safe_str(source.get("FEEDBACK_TAG"))
            feedback_text = safe_str(source.get("FEEDBACK_TEXT"))
            
            channel_id = safe_str(source.get("SOURCE"))
            user_id    = safe_str(source.get("USER_ID"))
            user_email = safe_str(source.get("USER_EMAIL"))
            user_phone = safe_str(source.get("USER_PHONE"))
            location   = safe_str(source.get("LOCATION"))
            locale     = safe_str(source.get("LOCALE"))
            device     = safe_str(source.get("DEVICE"))
            os_field   = safe_str(source.get("OS"))
            browser    = safe_str(source.get("BROWSER"))
            task       = 'message'
            custom     = safe_str(source.get("CUSTOM"))
            
            # KPI fields
            output_classifiers = safe_json_string(source.get("KPI_OUTPUT_CLASSIFIERS"))
            tokens_spent_prompt = source.get("KPI_TOKENS_SPENT_PROMPT", 0)
            tokens_spent_response = source.get("KPI_TOKENS_SPENT_RESPONSE", 0)
            readability_response = safe_float(source.get("KPI_READABILITY_RESPONSE"), 0.0)
            num_words_prompt = source.get("KPI_NUM_WORDS_PROMPT", 0)
            num_words_response = source.get("KPI_NUM_WORDS_RESPONSE", 0)
            lang_prompt = safe_str(source.get("KPI_LANG_PROMPT", [])[0] if isinstance(source.get("KPI_LANG_PROMPT"), list) else source.get("KPI_LANG_PROMPT"))
            lang_response = safe_str(source.get("KPI_LANG_RESPONSE", [])[0] if isinstance(source.get("KPI_LANG_RESPONSE"), list) else source.get("KPI_LANG_RESPONSE"))
            malicious_prompt = source.get("KPI_MALICIOUS_PROMPT", 0)
            malicious_prompt_score = safe_float(source.get("MALICIOUS_PROMPT_SCORE"), 0.0)
            purpose_label = safe_str(source.get("KPI_PURPOSE_LABEL"))
            sentiment_prompt = safe_str(source.get("KPI_SENTIMENT_PROMPT", [])[0] if isinstance(source.get("KPI_SENTIMENT_PROMPT"), list) else source.get("KPI_SENTIMENT_PROMPT"))
            sentiment_prompt_positive = safe_float(source.get("KPI_SENTIMENT_PROMPT_POS"), 0.0)
            sentiment_prompt_negative = safe_float(source.get("KPI_SENTIMENT_PROMPT_NEG"), 0.0)
            sentiment_prompt_neutral  = safe_float(source.get("KPI_SENTIMENT_PROMPT_NP"), 0.0)
            sentiment_response = safe_str(source.get("KPI_SENTIMENT_RESPONSE", [])[0] if isinstance(source.get("KPI_SENTIMENT_RESPONSE"), list) else source.get("KPI_SENTIMENT_RESPONSE"))
            sentiment_response_positive = safe_float(source.get("KPI_SENTIMENT_RESPONSE_POS"), 0.0)
            sentiment_response_negative = safe_float(source.get("KPI_SENTIMENT_RESPONSE_NEG"), 0.0)
            sentiment_response_neutral  = safe_float(source.get("KPI_SENTIMENT_RESPONSE_NP"), 0.0)
            
            # PII fields
            pii_phone_prompt = safe_int(source.get("KPI_PII_PHONE_PROMPT"))
            pii_phone_response = safe_int(source.get("KPI_PII_PHONE_RESPONSE"))
            pii_crypto_prompt = safe_int(source.get("KPI_PII_CRYPTO_PROMPT"))
            pii_crypto_response = safe_int(source.get("KPI_PII_CRYPTO_RESPONSE"))
            pii_email_prompt = safe_int(source.get("KPI_PII_EMAIL_PROMPT"))
            pii_email_response = safe_int(source.get("KPI_PII_EMAIL_RESPONSE"))
            pii_card_prompt = safe_int(source.get("KPI_PII_CARD_PROMPT"))
            pii_card_response = safe_int(source.get("KPI_PII_CARD_RESPONSE"))
            pii_bank_prompt = safe_int(source.get("KPI_PII_BANK_PROMPT"))
            pii_bank_response = safe_int(source.get("KPI_PII_BANK_RESPONSE"))
            pii_ip_prompt = safe_int(source.get("KPI_PII_IP_PROMPT"))
            pii_ip_response = safe_int(source.get("KPI_PII_IP_RESPONSE"))
            pii_person_prompt = safe_int(source.get("KPI_PII_PERSON_PROMPT"))
            pii_person_response = safe_int(source.get("KPI_PII_PERSON_RESPONSE"))
            pii_personal_prompt = safe_int(source.get("KPI_PII_PERSONAL_PROMPT"))
            pii_personal_response = safe_int(source.get("KPI_PII_PERSONAL_RESPONSE"))
            pii_company_prompt = safe_int(source.get("KPI_PII_COMPANY_PROMPT"))
            pii_company_response = safe_int(source.get("KPI_PII_COMPANY_RESPONSE"))
            pii_medical_prompt = safe_int(source.get("KPI_PII_MEDICAL_PROMPT"))
            pii_medical_response = safe_int(source.get("KPI_PII_MEDICAL_RESPONSE"))
            pii_passport_prompt = safe_int(source.get("KPI_PII_PASSPORT_PROMPT"))
            pii_passport_response = safe_int(source.get("KPI_PII_PASSPORT_RESPONSE"))
            pii_driving_prompt = safe_int(source.get("KPI_PII_DRIVING_PROMPT"))
            pii_driving_response = safe_int(source.get("KPI_PII_DRIVING_RESPONSE"))
            pii_prompt = safe_int(source.get("KPI_PII_PROMPT"))
            pii_response = safe_int(source.get("KPI_PII_RESPONSE"))
            
            # These are arrays of strings in your schema
            pii_prompt_label = safe_array_str(source.get("KPI_PII_PROMPT_LABEL", []))
            pii_response_label = safe_array_str(source.get("KPI_PII_RESPONSE_LABEL", []))
            
            # Build the row for insertion
            rows.append((
                app_id,
                team_id,
                trace_id,
                parent_id,
                interaction_id,
                conversation_id,
                session_id,
                start_timestamp,
                end_timestamp,
                latency,
                input_text,
                output_text,
                feedback_tag,
                feedback_text,
                channel_id,
                user_id,
                user_email,
                user_phone,
                location,
                locale,
                device,
                os_field,
                browser,
                task,
                custom,

                output_classifiers,
                tokens_spent_prompt,
                tokens_spent_response,
                readability_response,
                num_words_prompt,
                num_words_response,
                lang_prompt,
                lang_response,
                malicious_prompt,
                malicious_prompt_score,
                purpose_label,
                sentiment_prompt,
                sentiment_prompt_positive,
                sentiment_prompt_negative,
                sentiment_prompt_neutral,
                sentiment_response,
                sentiment_response_positive,
                sentiment_response_negative,
                sentiment_response_neutral,

                pii_phone_prompt,
                pii_phone_response,
                pii_crypto_prompt,
                pii_crypto_response,
                pii_email_prompt,
                pii_email_response,
                pii_card_prompt,
                pii_card_response,
                pii_bank_prompt,
                pii_bank_response,
                pii_ip_prompt,
                pii_ip_response,
                pii_person_prompt,
                pii_person_response,
                pii_personal_prompt,
                pii_personal_response,
                pii_company_prompt,
                pii_company_response,
                pii_medical_prompt,
                pii_medical_response,
                pii_passport_prompt,
                pii_passport_response,
                pii_driving_prompt,
                pii_driving_response,
                pii_prompt,
                pii_response,
                pii_prompt_label,
                pii_response_label
            ))
            
            # Insert in batches
            if len(rows) >= batch_size:
                client.execute(insert_query, rows)
                rows.clear()
    
    # Insert any remaining rows
    if rows:
        client.execute(insert_query, rows)


if __name__ == "__main__":
    main() 