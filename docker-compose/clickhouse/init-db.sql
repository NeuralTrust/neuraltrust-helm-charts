-- Create the database
CREATE DATABASE IF NOT EXISTS neuraltrust;

-- Switch to the database
USE neuraltrust;

-- Teams table
CREATE TABLE IF NOT EXISTS teams
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
    updatedAt DateTime64(6, 'UTC'),
    PRIMARY KEY (id)
) ENGINE = MergeTree()
ORDER BY (id);

-- Apps table
CREATE TABLE IF NOT EXISTS apps
(
    id String,
    name String,
    teamId String,
    inputCost Float64,
    outputCost Float64,
    convTracking UInt8,
    userTracking UInt8,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC'),
    PRIMARY KEY (id)
) ENGINE = MergeTree()
ORDER BY (id);

-- Classifiers table
CREATE TABLE IF NOT EXISTS classifiers
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
    updatedAt DateTime64(6, 'UTC'),
    PRIMARY KEY (id)
) ENGINE = MergeTree()
ORDER BY (id);

-- Classes table
CREATE TABLE IF NOT EXISTS classes
(
    id UInt32,
    name String,
    classifierId UInt32,
    description String,
    createdAt DateTime64(6, 'UTC'),
    updatedAt DateTime64(6, 'UTC'),
    PRIMARY KEY (id)
) ENGINE = MergeTree()
ORDER BY (id);

-- Raw traces table
CREATE TABLE IF NOT EXISTS traces
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
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_hour, app_id, conversation_id, interaction_id)
TTL event_date + INTERVAL 6 MONTH
SETTINGS index_granularity = 8192;

-- Processed traces table with KPIs
CREATE TABLE IF NOT EXISTS traces_processed
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
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_HOUR, APP_ID, CONVERSATION_ID, INTERACTION_ID)
TTL EVENT_DATE + INTERVAL 6 MONTH
SETTINGS index_granularity = 8192;

-- Daily metrics for UI graphs (main materialized view)
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_usage_metrics
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    -- Store states for aggregation
    countState() as messages_count_state,
    uniqState(CONVERSATION_ID) as conversations_count_state,
    maxState(END_TIMESTAMP) as max_end_timestamp_state,
    minState(START_TIMESTAMP) as min_start_timestamp_state,
    -- Count single message conversations
    uniqState(if(conv_message_count = 1, CONVERSATION_ID, null)) as single_message_conv_state,
    avgState(NUM_WORDS_PROMPT) as avg_prompt_words_state,
    avgState(NUM_WORDS_RESPONSE) as avg_response_words_state,
    -- Token metrics
    sumState(TOKENS_SPENT_PROMPT) as prompt_tokens_state,
    sumState(TOKENS_SPENT_RESPONSE) as response_tokens_state,
    avgState(LATENCY) as avg_latency_state
FROM (
    SELECT 
        APP_ID,
        START_TIME,
        START_TIMESTAMP,
        END_TIMESTAMP,
        CONVERSATION_ID,
        NUM_WORDS_PROMPT,
        NUM_WORDS_RESPONSE,
        TOKENS_SPENT_PROMPT,
        TOKENS_SPENT_RESPONSE,
        LATENCY,
        EVENT_DATE,
        -- Count messages per conversation
        count() OVER (PARTITION BY APP_ID, CONVERSATION_ID) as conv_message_count
    FROM traces_processed
    WHERE TASK = 'message'
)
GROUP BY APP_ID, EVENT_DATE, day;

-- Language metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_language_metrics
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, LANG_PROMPT, day)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    LANG_PROMPT,
    count() as language_count
FROM traces_processed
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, day, LANG_PROMPT;

-- Create a view to calculate conversation message counts
CREATE VIEW conversation_message_counts AS
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CONVERSATION_ID,
    count() as message_count
FROM traces_processed
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, day, CONVERSATION_ID;

-- Create a view to calculate single message rate
CREATE VIEW single_message_rate_view AS
SELECT
    APP_ID,
    EVENT_DATE,
    day,
    countIf(message_count = 1) as single_message_conversations,
    count() as total_conversations,
    100.0 * countIf(message_count = 1) / count() as single_message_rate
FROM conversation_message_counts
GROUP BY APP_ID, EVENT_DATE, day;

-- User and session metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_user_metrics
ENGINE = AggregatingMergeTree()
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
    FROM traces_processed
    WHERE TASK = 'message' AND USER_ID != ''
)
GROUP BY APP_ID, EVENT_DATE, day;

-- Update the metrics view to include tokens per message metrics
CREATE OR REPLACE VIEW traces_metrics AS
SELECT
    m.APP_ID AS APP_ID,
    m.EVENT_DATE AS EVENT_DATE,
    m.day AS day,
    -- Basic metrics
    countMerge(m.messages_count_state) AS messages_count,
    uniqMerge(m.conversations_count_state) AS conversations_count,
    -- Calculated metrics
    countMerge(m.messages_count_state) / uniqMerge(m.conversations_count_state) as dialogue_volume,
    (maxMerge(m.max_end_timestamp_state) - minMerge(m.min_start_timestamp_state))/1000/60 as dialogue_time_minutes,
    -- Get single message rate from dedicated view
    s.single_message_rate,
    avgMerge(m.avg_prompt_words_state) as avg_prompt_words,
    avgMerge(m.avg_response_words_state) as avg_response_words,
    -- Token metrics
    sumMerge(m.prompt_tokens_state) as prompt_tokens,
    sumMerge(m.response_tokens_state) as response_tokens,
    avgMerge(m.avg_latency_state) as avg_latency,
    -- Tokens per message metrics
    if(countMerge(m.messages_count_state) > 0, 
       sumMerge(m.prompt_tokens_state) / countMerge(m.messages_count_state), 0) as prompt_tokens_per_message,
    if(countMerge(m.messages_count_state) > 0, 
       sumMerge(m.response_tokens_state) / countMerge(m.messages_count_state), 0) as response_tokens_per_message,
    -- Cost calculation
    sumMerge(m.prompt_tokens_state) * a.inputCost as prompt_cost,
    sumMerge(m.response_tokens_state) * a.outputCost as response_cost,
    sumMerge(m.prompt_tokens_state) * a.inputCost + sumMerge(m.response_tokens_state) * a.outputCost as total_cost,
    -- User metrics
    uniqMerge(u.users_count_state) as users_count,
    uniqMerge(u.new_users_count_state) as new_users_count,
    -- Session metrics
    uniqMerge(u.sessions_count_state) as sessions_count,
    -- Calculate sessions per user
    if(uniqMerge(u.users_count_state) > 0, 
       uniqMerge(u.sessions_count_state) / uniqMerge(u.users_count_state), 
       0) as sessions_per_user,
    -- Country metrics
    uniqMerge(u.countries_count_state) as countries_count,
    groupArrayMerge(u.countries_state) as countries
FROM traces_usage_metrics m
LEFT JOIN single_message_rate_view s ON m.APP_ID = s.APP_ID AND m.EVENT_DATE = s.EVENT_DATE AND m.day = s.day
LEFT JOIN traces_user_metrics u ON m.APP_ID = u.APP_ID AND m.EVENT_DATE = u.EVENT_DATE AND m.day = u.day
LEFT JOIN apps a ON m.APP_ID = a.id
GROUP BY m.APP_ID, m.EVENT_DATE, m.day, s.single_message_rate, a.inputCost, a.outputCost;

-- Create a view for country metrics
CREATE OR REPLACE VIEW traces_country_metrics AS
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    LOCATION as country,
    count() as count
FROM traces_processed
WHERE TASK = 'message' AND LOCATION != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), LOCATION
ORDER BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), count DESC;

-- Update the total metrics view to include user and session metrics
CREATE OR REPLACE VIEW traces_metrics_total AS
SELECT 
    m.APP_ID,
    sum(m.messages_count) as total_messages,
    sum(m.conversations_count) as total_conversations,
    avg(m.dialogue_volume) as avg_dialogue_volume,
    avg(m.dialogue_time_minutes) as avg_dialogue_time,
    avg(m.single_message_rate) as avg_single_message_rate,
    avg(m.avg_prompt_words) as avg_prompt_words,
    avg(m.avg_response_words) as avg_response_words,
    -- Token metrics
    sum(m.prompt_tokens) as total_prompt_tokens,
    sum(m.response_tokens) as total_response_tokens,
    avg(m.avg_latency) as avg_latency,
    -- Cost calculation
    sum(m.total_cost) as total_cost,
    -- User metrics
    sum(m.users_count) as total_users,
    sum(m.new_users_count) as total_new_users,
    -- Session metrics
    sum(m.sessions_count) as total_sessions,
    avg(m.sessions_per_user) as avg_sessions_per_user
FROM traces_metrics m
GROUP BY m.APP_ID;

-- Separate language metrics view
CREATE VIEW traces_language_daily AS
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
CREATE VIEW traces_language_total AS
SELECT
    APP_ID,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics
GROUP BY APP_ID, LANG_PROMPT
ORDER BY APP_ID, count DESC;

-- Drop the separate token metrics view since it's now redundant
DROP VIEW IF EXISTS traces_all_metrics;
DROP VIEW IF EXISTS traces_token_metrics;

-- Device metrics view
CREATE MATERIALIZED VIEW traces_device_metrics
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, DEVICE)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    DEVICE,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed
WHERE TASK = 'message' AND DEVICE != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), DEVICE;

-- Browser metrics view
CREATE MATERIALIZED VIEW traces_browser_metrics
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, BROWSER)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    BROWSER,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed
WHERE TASK = 'message' AND BROWSER != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), BROWSER;

-- OS metrics view
CREATE MATERIALIZED VIEW traces_os_metrics
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, OS)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    OS,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed
WHERE TASK = 'message' AND OS != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), OS;

-- Create a materialized view for sessions by channel
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_channel_metrics
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, channel)
AS
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CHANNEL_ID as channel,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed
WHERE TASK = 'message' AND CHANNEL_ID IS NOT NULL
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), CHANNEL_ID;

-- User engagement metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_engagement_metrics
ENGINE = AggregatingMergeTree()
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
    FROM traces_processed
    WHERE TASK = 'message' AND USER_ID != ''
    GROUP BY APP_ID, EVENT_DATE, START_TIME, USER_ID
)
GROUP BY APP_ID, EVENT_DATE, day;

-- Top users by requests view with AggregatingMergeTree engine
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_top_users
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, USER_ID)
AS 
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    USER_ID,
    countState() as request_count_state
FROM traces_processed
WHERE TASK = 'message' AND USER_ID != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), USER_ID;

-- Security metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_security_metrics
ENGINE = AggregatingMergeTree()
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
FROM traces_processed
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME);