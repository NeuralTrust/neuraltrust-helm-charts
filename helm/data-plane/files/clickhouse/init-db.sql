-- Create the database
CREATE DATABASE IF NOT EXISTS neuraltrust;

-- Switch to the database
USE neuraltrust;

-- Teams table - use ReplicatedMergeTree for better reliability
CREATE TABLE IF NOT EXISTS teams_local ON CLUSTER '{cluster}'
(
    id String,
    name String,
    type String,
    modelProvider String,
    modelBaseUrl String,
    modelApiKey String,
    modelName String,
    modelApiVersion String,
    modelDeploymentName String,
    modelExtraHeaders String,
    dataPlaneEndpoint String,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC')
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/teams', '{replica}')
ORDER BY (id);

-- Create a Distributed table for teams
CREATE TABLE IF NOT EXISTS teams ON CLUSTER '{cluster}' AS teams_local
ENGINE = Distributed('{cluster}', neuraltrust, teams_local, rand());

-- Apps table
CREATE TABLE IF NOT EXISTS apps_local ON CLUSTER '{cluster}'
(
    id String,
    name String,
    teamId String,
    inputCost Float64,
    outputCost Float64,
    convTracking UInt8,
    userTracking UInt8,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC')
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/apps', '{replica}')
ORDER BY (id);

-- Create a Distributed table for apps
CREATE TABLE IF NOT EXISTS apps ON CLUSTER '{cluster}' AS apps_local
ENGINE = Distributed('{cluster}', neuraltrust, apps_local, rand());

-- Classifiers table
CREATE TABLE IF NOT EXISTS classifiers_local ON CLUSTER '{cluster}'
(
    id UInt32,
    name String,
    scope String,
    enabled UInt8,
    appId String,
    description String,
    instructions String,
    type String,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC')
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/classifiers', '{replica}')
ORDER BY (id);

-- Create a Distributed table for classifiers
CREATE TABLE IF NOT EXISTS classifiers ON CLUSTER '{cluster}' AS classifiers_local
ENGINE = Distributed('{cluster}', neuraltrust, classifiers_local, rand());

-- Classes table
CREATE TABLE IF NOT EXISTS classes_local ON CLUSTER '{cluster}'
(
    id UInt32,
    name String,
    classifierId UInt32,
    description String,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC')
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/classes', '{replica}')
ORDER BY (id);

-- Create a Distributed table for classes
CREATE TABLE IF NOT EXISTS classes ON CLUSTER '{cluster}' AS classes_local
ENGINE = Distributed('{cluster}', neuraltrust, classes_local, rand());

-- Raw traces table - shard by app_id for better distribution
CREATE TABLE IF NOT EXISTS traces_local ON CLUSTER '{cluster}'
(
    app_id String,
    team_id String,
    trace_id String,
    parent_id String,
    interaction_id String,
    conversation_id String,
    start_timestamp Int64,
    end_timestamp Int64,
    start_time DateTime MATERIALIZED fromUnixTimestamp64Milli(start_timestamp),
    end_time DateTime MATERIALIZED fromUnixTimestamp64Milli(end_timestamp),
    latency Int32,
    input String,
    output String,
    feedback_tag String,
    feedback_text String,
    channel_id String,
    session_id String,
    user_id String,
    user_email String,
    user_phone String,
    location String,
    locale String,
    device String,
    os String,
    browser String,
    task String,
    custom String,
    event_date Date MATERIALIZED toDate(start_time),
    event_hour DateTime MATERIALIZED toStartOfHour(start_time)
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/traces', '{replica}')
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_hour, app_id, conversation_id, interaction_id)
TTL event_date + INTERVAL 6 MONTH
SETTINGS index_granularity = 8192;

-- Create a Distributed table for traces
CREATE TABLE IF NOT EXISTS traces ON CLUSTER '{cluster}' AS traces_local
ENGINE = Distributed('{cluster}', neuraltrust, traces_local, cityHash64(app_id));

-- Processed traces table with KPIs - shard by APP_ID
CREATE TABLE IF NOT EXISTS traces_processed_local ON CLUSTER '{cluster}'
(
    -- Base fields from traces
    APP_ID String,
    TEAM_ID String,
    TRACE_ID String,
    PARENT_ID String,
    INTERACTION_ID String,
    CONVERSATION_ID String,
    SESSION_ID String,
    START_TIMESTAMP Int64,
    END_TIMESTAMP Int64,
    START_TIME DateTime MATERIALIZED fromUnixTimestamp64Milli(START_TIMESTAMP),
    END_TIME DateTime MATERIALIZED fromUnixTimestamp64Milli(END_TIMESTAMP),
    LATENCY Int32,
    INPUT String,
    OUTPUT String,
    FEEDBACK_TAG String,
    FEEDBACK_TEXT String,
    CHANNEL_ID String,
    USER_ID String,
    USER_EMAIL String,
    USER_PHONE String,
    LOCATION String,
    LOCALE String,
    DEVICE String,
    OS String,
    BROWSER String,
    TASK String,
    CUSTOM String,

    -- KPI fields
    OUTPUT_CLASSIFIERS Nested(
        ID Int32,
        CATEGORY String,
        LABEL Array(String),
        SCORE Int32
    ),
    TOKENS_SPENT_PROMPT Int32,
    TOKENS_SPENT_RESPONSE Int32,
    READABILITY_PROMPT Float64,
    READABILITY_RESPONSE Float64,
    NUM_WORDS_PROMPT Int32,
    NUM_WORDS_RESPONSE Int32,
    LANG_PROMPT String,
    LANG_RESPONSE String,
    MALICIOUS_PROMPT Int32,
    MALICIOUS_PROMPT_SCORE Float64,
    PURPOSE_LABEL String,
    SENTIMENT_PROMPT String,
    SENTIMENT_PROMPT_POSITIVE Float64,
    SENTIMENT_PROMPT_NEGATIVE Float64,
    SENTIMENT_PROMPT_NEUTRAL Float64,
    SENTIMENT_RESPONSE String,
    SENTIMENT_RESPONSE_POSITIVE Float64,
    SENTIMENT_RESPONSE_NEGATIVE Float64,
    SENTIMENT_RESPONSE_NEUTRAL Float64,
    
    -- PII fields
    PII_PHONE_PROMPT Int32,
    PII_PHONE_RESPONSE Int32,
    PII_CRYPTO_PROMPT Int32,
    PII_CRYPTO_RESPONSE Int32,
    PII_EMAIL_PROMPT Int32,
    PII_EMAIL_RESPONSE Int32,
    PII_CARD_PROMPT Int32,
    PII_CARD_RESPONSE Int32,
    PII_BANK_PROMPT Int32,
    PII_BANK_RESPONSE Int32,
    PII_IP_PROMPT Int32,
    PII_IP_RESPONSE Int32,
    PII_PERSON_PROMPT Int32,
    PII_PERSON_RESPONSE Int32,
    PII_PERSONAL_PROMPT Int32,
    PII_PERSONAL_RESPONSE Int32,
    PII_COMPANY_PROMPT Int32,
    PII_COMPANY_RESPONSE Int32,
    PII_MEDICAL_PROMPT Int32,
    PII_MEDICAL_RESPONSE Int32,
    PII_PASSPORT_PROMPT Int32,
    PII_PASSPORT_RESPONSE Int32,
    PII_DRIVING_PROMPT Int32,
    PII_DRIVING_RESPONSE Int32,
    PII_PROMPT Int32,
    PII_RESPONSE Int32,
    PII_PROMPT_LABEL Array(String),
    PII_RESPONSE_LABEL Array(String),

    -- Partitioning fields
    EVENT_DATE Date MATERIALIZED toDate(START_TIME),
    EVENT_HOUR DateTime MATERIALIZED toStartOfHour(START_TIME)
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/traces_processed', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_HOUR, APP_ID, CONVERSATION_ID, INTERACTION_ID)
TTL EVENT_DATE + INTERVAL 6 MONTH
SETTINGS index_granularity = 8192;

-- Create a Distributed table for processed traces
CREATE TABLE IF NOT EXISTS traces_processed ON CLUSTER '{cluster}' AS traces_processed_local
ENGINE = Distributed('{cluster}', neuraltrust, traces_processed_local, cityHash64(APP_ID));

-- User and session metrics view - use ReplicatedAggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_user_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_user_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    -- User metrics
    uniqState(USER_ID) as users_count_state,
    uniqState(if(is_first_time, USER_ID, null)) as new_users_count_state,
    -- Session metrics
    uniqState(SESSION_ID) as sessions_count_state,
    -- Location metrics
    uniqState(LOCATION) as countries_count_state,
    groupArrayState(LOCATION) as countries_state
FROM (
    SELECT 
        APP_ID,
        START_TIME,
        EVENT_DATE,
        USER_ID,
        SESSION_ID,
        LOCATION,
        -- Determine if this is the user's first interaction
        min(START_TIMESTAMP) OVER (PARTITION BY APP_ID, USER_ID) = START_TIMESTAMP as is_first_time
    FROM traces_processed_local
    WHERE TASK = 'message' AND USER_ID != ''
)
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME);

-- Create a Distributed view for user metrics
CREATE TABLE IF NOT EXISTS traces_user_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_user_metrics_local, rand());

-- Language metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_language_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_language_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, LANG_PROMPT)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    LANG_PROMPT,
    count() as language_count
FROM traces_processed_local
WHERE TASK = 'message' AND LANG_PROMPT != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), LANG_PROMPT;

-- Create a Distributed view for language metrics
CREATE TABLE IF NOT EXISTS traces_language_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_language_metrics_local, rand());

-- Metrics view with SummingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    
    -- Message metrics
    count() as messages_count,
    uniqCombined(CONVERSATION_ID) as conversations_count,
    avg(arrayLength(splitByChar(' ', INPUT))) as avg_prompt_words,
    avg(arrayLength(splitByChar(' ', OUTPUT))) as avg_response_words,
    
    -- Token metrics
    sum(TOKENS_SPENT_PROMPT) as prompt_tokens,
    sum(TOKENS_SPENT_RESPONSE) as response_tokens,
    avg(TOKENS_SPENT_PROMPT) as prompt_tokens_per_message,
    avg(TOKENS_SPENT_RESPONSE) as response_tokens_per_message,
    
    -- Latency metrics
    avg(LATENCY) as avg_latency,
    
    -- Cost metrics (assuming $0.01 per 1K tokens)
    (sum(TOKENS_SPENT_PROMPT) + sum(TOKENS_SPENT_RESPONSE)) * 0.01 / 1000 as total_cost,
    
    -- User metrics
    uniqCombined(USER_ID) as users_count,
    uniqCombinedIf(USER_ID, is_first_time) as new_users_count,
    
    -- Session metrics
    uniqCombined(SESSION_ID) as sessions_count,
    if(uniqCombined(USER_ID) > 0, uniqCombined(SESSION_ID) / uniqCombined(USER_ID), 0) as sessions_per_user,
    
    -- Dialogue metrics
    avg(messages_per_conversation) as dialogue_volume,
    avg(conversation_duration_minutes) as dialogue_time_minutes,
    countIf(messages_per_conversation = 1) / count() as single_message_rate
FROM (
    SELECT
        APP_ID,
        EVENT_DATE,
        START_TIME,
        CONVERSATION_ID,
        USER_ID,
        SESSION_ID,
        INPUT,
        OUTPUT,
        TOKENS_SPENT_PROMPT,
        TOKENS_SPENT_RESPONSE,
        LATENCY,
        -- Calculate if this is the user's first message
        min(START_TIMESTAMP) OVER (PARTITION BY APP_ID, USER_ID) = START_TIMESTAMP as is_first_time,
        -- Calculate messages per conversation
        count() OVER (PARTITION BY APP_ID, CONVERSATION_ID) as messages_per_conversation,
        -- Calculate conversation duration in minutes
        (max(END_TIMESTAMP) OVER (PARTITION BY APP_ID, CONVERSATION_ID) - 
         min(START_TIMESTAMP) OVER (PARTITION BY APP_ID, CONVERSATION_ID)) / 60000.0 as conversation_duration_minutes
    FROM traces_processed_local
    WHERE TASK = 'message'
)
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME);

-- Create a Distributed view for metrics
CREATE TABLE IF NOT EXISTS traces_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_metrics_local, rand());

-- Create summary views for total metrics
CREATE VIEW traces_metrics_total ON CLUSTER '{cluster}' AS
SELECT
    APP_ID,
    -- Message metrics
    sum(messages_count) as total_messages,
    sum(conversations_count) as total_conversations,
    avg(avg_prompt_words) as avg_prompt_words,
    avg(avg_response_words) as avg_response_words,
    
    -- Token metrics
    sum(prompt_tokens) as total_prompt_tokens,
    sum(response_tokens) as total_response_tokens,
    sum(prompt_tokens) / sum(messages_count) as avg_prompt_tokens_per_message,
    sum(response_tokens) / sum(messages_count) as avg_response_tokens_per_message,
    
    -- Latency metrics
    avg(avg_latency) as avg_latency,
    
    -- Cost metrics
    sum(total_cost) as total_cost,
    
    -- User metrics
    sum(users_count) as total_users,
    sum(new_users_count) as total_new_users,
    
    -- Session metrics
    sum(sessions_count) as total_sessions,
    avg(sessions_per_user) as avg_sessions_per_user
FROM traces_metrics
GROUP BY APP_ID;

-- Separate language metrics view
CREATE VIEW traces_language_daily ON CLUSTER '{cluster}' AS
SELECT
    APP_ID,
    EVENT_DATE,
    day,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics
GROUP BY APP_ID, EVENT_DATE, day, LANG_PROMPT
ORDER BY APP_ID, EVENT_DATE, day, count DESC;

-- Total language metrics view
CREATE VIEW traces_language_total ON CLUSTER '{cluster}' AS
SELECT
    APP_ID,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics
GROUP BY APP_ID, LANG_PROMPT
ORDER BY APP_ID, count DESC;

-- Device metrics view
CREATE MATERIALIZED VIEW traces_device_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_device_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, DEVICE)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    DEVICE,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND DEVICE != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), DEVICE;

-- Create a Distributed view for device metrics
CREATE TABLE IF NOT EXISTS traces_device_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_device_metrics_local, rand());

-- Browser metrics view
CREATE MATERIALIZED VIEW traces_browser_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_browser_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, BROWSER)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    BROWSER,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND BROWSER != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), BROWSER;

-- Create a Distributed view for browser metrics
CREATE TABLE IF NOT EXISTS traces_browser_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_browser_metrics_local, rand());

-- OS metrics view
CREATE MATERIALIZED VIEW traces_os_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_os_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, OS)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    OS,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND OS != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), OS;

-- Create a Distributed view for OS metrics
CREATE TABLE IF NOT EXISTS traces_os_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_os_metrics_local, rand());

-- Create a materialized view for sessions by channel
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_channel_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_channel_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, channel)
AS
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CHANNEL_ID as channel,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND CHANNEL_ID IS NOT NULL
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), CHANNEL_ID;

-- Create a Distributed view for channel metrics
CREATE TABLE IF NOT EXISTS traces_channel_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_channel_metrics_local, rand());

-- User engagement metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_engagement_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_engagement_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    -- Active users (users with more than 3 messages)
    uniqState(USER_ID) as active_users_state,
    -- Total API calls
    sumState(API_CALLS) as total_calls_state,
    -- Store user-level data for calculating avg and max
    groupArrayState((USER_ID, API_CALLS)) as user_calls_state
FROM (
    SELECT
        APP_ID,
        EVENT_DATE,
        START_TIME,
        USER_ID,
        count() as MESSAGE_COUNT,
        count() as API_CALLS
    FROM traces_processed_local
    WHERE TASK = 'message' AND USER_ID != ''
    GROUP BY APP_ID, EVENT_DATE, START_TIME, USER_ID
)
GROUP BY APP_ID, EVENT_DATE, day;

-- Create a Distributed view for engagement metrics
CREATE TABLE IF NOT EXISTS traces_engagement_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_engagement_metrics_local, rand());

-- Top users by requests view with AggregatingMergeTree engine
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_top_users_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_top_users', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, USER_ID)
AS 
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    USER_ID,
    countState() as request_count_state
FROM traces_processed_local
WHERE TASK = 'message' AND USER_ID != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), USER_ID;

-- Create a Distributed view for top users
CREATE TABLE IF NOT EXISTS traces_top_users ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_top_users_local, rand());

-- Security metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_security_metrics_local ON CLUSTER '{cluster}'
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_security_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    -- Malicious content metrics
    sumState(MALICIOUS_PROMPT) as malicious_prompt_state,
    avgState(MALICIOUS_PROMPT_SCORE) as malicious_score_state,
    
    -- PII metrics - overall
    sumState(PII_PROMPT) as pii_prompt_state,
    sumState(PII_RESPONSE) as pii_response_state,
    
    -- PII metrics - detailed breakdown
    sumState(PII_PHONE_PROMPT) as pii_phone_prompt_state,
    sumState(PII_PHONE_RESPONSE) as pii_phone_response_state,
    sumState(PII_CRYPTO_PROMPT) as pii_crypto_prompt_state,
    sumState(PII_CRYPTO_RESPONSE) as pii_crypto_response_state,
    sumState(PII_EMAIL_PROMPT) as pii_email_prompt_state,
    sumState(PII_EMAIL_RESPONSE) as pii_email_response_state,
    sumState(PII_CARD_PROMPT) as pii_card_prompt_state,
    sumState(PII_CARD_RESPONSE) as pii_card_response_state,
    sumState(PII_BANK_PROMPT) as pii_bank_prompt_state,
    sumState(PII_BANK_RESPONSE) as pii_bank_response_state,
    sumState(PII_IP_PROMPT) as pii_ip_prompt_state,
    sumState(PII_IP_RESPONSE) as pii_ip_response_state,
    sumState(PII_PERSON_PROMPT) as pii_person_prompt_state,
    sumState(PII_PERSON_RESPONSE) as pii_person_response_state,
    sumState(PII_PERSONAL_PROMPT) as pii_personal_prompt_state,
    sumState(PII_PERSONAL_RESPONSE) as pii_personal_response_state,
    sumState(PII_COMPANY_PROMPT) as pii_company_prompt_state,
    sumState(PII_COMPANY_RESPONSE) as pii_company_response_state,
    sumState(PII_MEDICAL_PROMPT) as pii_medical_prompt_state,
    sumState(PII_MEDICAL_RESPONSE) as pii_medical_response_state,
    sumState(PII_PASSPORT_PROMPT) as pii_passport_prompt_state,
    sumState(PII_PASSPORT_RESPONSE) as pii_passport_response_state,
    sumState(PII_DRIVING_PROMPT) as pii_driving_prompt_state,
    sumState(PII_DRIVING_RESPONSE) as pii_driving_response_state,
    
    -- Count of messages with PII
    countStateIf(1, PII_PROMPT > 0) as pii_prompt_messages_state,
    countStateIf(1, PII_RESPONSE > 0) as pii_response_messages_state,
    
    -- Count of messages with malicious content
    countStateIf(1, MALICIOUS_PROMPT > 0) as malicious_messages_state
FROM traces_processed_local
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME);

-- Create a Distributed view for security metrics
CREATE TABLE IF NOT EXISTS traces_security_metrics ON CLUSTER '{cluster}'
ENGINE = Distributed('{cluster}', neuraltrust, traces_security_metrics_local, rand());