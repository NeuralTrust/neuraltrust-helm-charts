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

-- Tests table
CREATE TABLE IF NOT EXISTS tests (
    id String,
    scenarioId String,
    appId String,
    testCase String, -- JSON in ClickHouse is stored as String
    context String,  -- JSON in ClickHouse is stored as String
    type String,
    contextKeys Array(String),
    createdAt DateTime DEFAULT now(),
    updatedAt DateTime DEFAULT now(),
    sign Int8
) ENGINE = CollapsingMergeTree(sign)
ORDER BY (id, scenarioId, appId);

-- Tests Runs table
CREATE TABLE IF NOT EXISTS test_runs (
    id String,
    scenarioId String,
    appId String,
    testId String,
    executionId String,
    type String,
    contextKeys Array(String),
    failure UInt8, -- Boolean in ClickHouse is represented as UInt8 (0 or 1)
    failCriteria String,
    testCase String, -- JSON stored as String
    score String,    -- JSON stored as String
    executionTimeSeconds Int32 NULL,
    runAt DateTime DEFAULT now(),
    sign Int8,
    PRIMARY KEY (id)
) ENGINE = CollapsingMergeTree(sign)
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
    FEEDBACK_TAG String DEFAULT '',
    FEEDBACK_TEXT String DEFAULT '',
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
    OUTPUT_CLASSIFIERS String, -- Store as JSON string
    TOKENS_SPENT_PROMPT Int32,
    TOKENS_SPENT_RESPONSE Int32,
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
    -- Message and conversation counts
    uniqState(INTERACTION_ID) as messages_count_state,
    uniqState(CONVERSATION_ID) as conversations_count_state,
    -- Timestamp metrics for calculating dialogue time
    minState(START_TIMESTAMP) as min_start_timestamp_state,
    maxState(END_TIMESTAMP) as max_end_timestamp_state,
    -- Word count metrics
    avgState(NUM_WORDS_PROMPT) as avg_prompt_words_state,
    avgState(NUM_WORDS_RESPONSE) as avg_response_words_state,
    -- Token metrics
    sumState(TOKENS_SPENT_PROMPT) as prompt_tokens_state,
    sumState(TOKENS_SPENT_RESPONSE) as response_tokens_state,
    avgState(LATENCY) as avg_latency_state,
    -- Sentiment metrics
    sumState(SENTIMENT_PROMPT_POSITIVE) as sentiment_prompt_positive_state,
    sumState(SENTIMENT_PROMPT_NEGATIVE) as sentiment_prompt_negative_state,
    sumState(SENTIMENT_RESPONSE_POSITIVE) as sentiment_response_positive_state,
    sumState(SENTIMENT_RESPONSE_NEGATIVE) as sentiment_response_negative_state,
    -- Readability metrics
    avgState(READABILITY_RESPONSE) as readability_response_state,
    -- Feedback metrics
    countStateIf(1, FEEDBACK_TAG = 'positive') as feedback_positive_count_state,
    countStateIf(1, FEEDBACK_TAG = 'negative') as feedback_negative_count_state
FROM traces_processed
WHERE TASK = 'message'
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
CREATE VIEW IF NOT EXISTS conversation_message_counts AS
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
CREATE VIEW IF NOT EXISTS single_message_rate_view AS
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

-- Create a view for metrics analysis
CREATE OR REPLACE VIEW traces_metrics AS
SELECT
    m.APP_ID AS APP_ID,
    m.EVENT_DATE AS EVENT_DATE,
    m.day AS day,
    -- Basic metrics
    uniqMerge(m.messages_count_state) AS messages_count,
    uniqMerge(m.conversations_count_state) AS conversations_count,
    -- Calculated metrics
    uniqMerge(m.messages_count_state) / uniqMerge(m.conversations_count_state) as dialogue_volume,
    -- Use the accurate dialogue time from conversations view
    max(c.TIME_TOTAL) as dialogue_time_seconds,
    -- Get single message rate from dedicated view
    s.single_message_rate,
    avgMerge(m.avg_prompt_words_state) as avg_prompt_words,
    avgMerge(m.avg_response_words_state) as avg_response_words,
    -- Token metrics
    sumMerge(m.prompt_tokens_state) as prompt_tokens,
    sumMerge(m.response_tokens_state) as response_tokens,
    avgMerge(m.avg_latency_state) as avg_latency,
    -- Tokens per message metrics
    if(uniqMerge(m.messages_count_state) > 0,
       sumMerge(m.prompt_tokens_state) / uniqMerge(m.messages_count_state), 0) as prompt_tokens_per_message,
    if(uniqMerge(m.messages_count_state) > 0,
       sumMerge(m.response_tokens_state) / uniqMerge(m.messages_count_state), 0) as response_tokens_per_message,
    -- Cost calculation
    sumMerge(m.prompt_tokens_state) * if(a.inputCost IS NULL, 0, a.inputCost) as prompt_cost,
    sumMerge(m.response_tokens_state) * if(a.outputCost IS NULL, 0, a.outputCost) as response_cost,
    sumMerge(m.prompt_tokens_state) * if(a.inputCost IS NULL, 0, a.inputCost) + 
    sumMerge(m.response_tokens_state) * if(a.outputCost IS NULL, 0, a.outputCost) as total_cost,
    -- User metrics
    uniqMerge(u.users_count_state) as users_count,
    uniqMerge(u.new_users_count_state) as new_users_count,
    -- Session metrics
    uniqMerge(u.sessions_count_state) as sessions_count,
    -- Calculate sessions per user
    if(uniqMerge(u.users_count_state) > 0, 
       uniqMerge(u.sessions_count_state) / uniqMerge(u.users_count_state), 
       0) as sessions_per_user,
    
    -- Sentiment metrics
    sumMerge(m.sentiment_prompt_positive_state) AS sentiment_prompt_positive,
    sumMerge(m.sentiment_prompt_negative_state) AS sentiment_prompt_negative,
    sumMerge(m.sentiment_response_positive_state) AS sentiment_response_positive,
    sumMerge(m.sentiment_response_negative_state) AS sentiment_response_negative,
    
    -- Sentiment rate metrics (percentage of messages with positive/negative sentiment)
    100.0 * sumMerge(m.sentiment_prompt_positive_state) / uniqMerge(m.messages_count_state) as sentiment_prompt_positive_rate,
    100.0 * sumMerge(m.sentiment_prompt_negative_state) / uniqMerge(m.messages_count_state) as sentiment_prompt_negative_rate,
    100.0 * sumMerge(m.sentiment_response_positive_state) / uniqMerge(m.messages_count_state) as sentiment_response_positive_rate,
    100.0 * sumMerge(m.sentiment_response_negative_state) / uniqMerge(m.messages_count_state) as sentiment_response_negative_rate,
    
    -- Readability metrics
    avgMerge(m.readability_response_state) as readability,
    
    -- Feedback metrics
    countMerge(m.feedback_positive_count_state) as feedback_positive,
    countMerge(m.feedback_negative_count_state) as feedback_negative,
    100.0 * countMerge(m.feedback_positive_count_state) / uniqMerge(m.messages_count_state) as feedback_positive_rate,
    100.0 * countMerge(m.feedback_negative_count_state) / uniqMerge(m.messages_count_state) as feedback_negative_rate
FROM traces_usage_metrics m
LEFT JOIN single_message_rate_view s ON m.APP_ID = s.APP_ID AND m.EVENT_DATE = s.EVENT_DATE AND m.day = s.day
LEFT JOIN traces_user_metrics u ON m.APP_ID = u.APP_ID AND m.EVENT_DATE = u.EVENT_DATE AND m.day = u.day
LEFT JOIN traces_conversations_view c ON m.APP_ID = c.APP_ID
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

-- Update the total metrics view to include READABILITY metrics
CREATE OR REPLACE VIEW traces_metrics_total AS
SELECT 
    m.APP_ID,
    sum(m.messages_count) as total_messages,
    sum(m.conversations_count) as total_conversations,
    avg(m.dialogue_volume) as avg_dialogue_volume,
    avg(m.dialogue_time_seconds) as avg_dialogue_time,
    avg(m.single_message_rate) as avg_single_message_rate,
    avg(m.avg_prompt_words) as avg_prompt_words,
    avg(m.avg_response_words) as avg_response_words,
    -- Token metrics
    sum(m.prompt_tokens) as total_prompt_tokens,
    sum(m.response_tokens) as total_response_tokens,
    avg(m.avg_latency) as avg_latency,
    -- Cost calculation
    sum(m.prompt_cost) as prompt_cost,
    sum(m.response_cost) as response_cost,
    sum(m.total_cost) as total_cost,
    -- User metrics
    sum(m.users_count) as total_users,
    sum(m.new_users_count) as total_new_users,
    -- Session metrics
    sum(m.sessions_count) as total_sessions,
    avg(m.sessions_per_user) as avg_sessions_per_user,
    -- Sentiment metrics
    avg(m.sentiment_prompt_positive) as sentiment_prompt_positive,
    avg(m.sentiment_prompt_negative) as sentiment_prompt_negative,
    avg(m.sentiment_response_positive) as sentiment_response_positive,
    avg(m.sentiment_response_negative) as sentiment_response_negative,
    -- Readability metrics
    avg(m.readability) as readability,
    -- Feedback metrics
    avg(m.feedback_positive_rate) as feedback_positive_rate,
    avg(m.feedback_negative_rate) as feedback_negative_rate
FROM traces_metrics m
GROUP BY m.APP_ID;

-- Separate language metrics view
CREATE VIEW IF NOT EXISTS traces_language_daily AS
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
CREATE VIEW IF NOT EXISTS traces_language_total AS
SELECT
    APP_ID,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics
GROUP BY APP_ID, LANG_PROMPT
ORDER BY APP_ID, count DESC;


-- Device metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_device_metrics
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
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_browser_metrics
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
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_os_metrics
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

-- First, create a materialized view to collect user engagement data
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_user_engagement_data
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, USER_ID)
AS SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    USER_ID,
    -- Count interactions per user
    count() as interaction_count
FROM traces_processed
WHERE USER_ID != ''
GROUP BY APP_ID, EVENT_DATE, day, USER_ID;

-- Then create a regular view on top of the materialized view
CREATE OR REPLACE VIEW traces_engagement_metrics AS
SELECT
    APP_ID,
    EVENT_DATE,
    day,
    -- User metrics
    uniqExact(USER_ID) as active_users,
    -- Average calls per user
    sum(interaction_count) / uniqExact(USER_ID) as avg_calls_per_user,
    -- Maximum calls per user
    max(interaction_count) as max_calls_per_user
FROM traces_user_engagement_data
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

-- Create a materialized view with its own storage engine for conversation aggregation
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_conversations
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (APP_ID, CONVERSATION_ID)
AS SELECT
    APP_ID,
    CONVERSATION_ID,
    toDate(START_TIMESTAMP / 1000) as EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    min(START_TIMESTAMP) as FIRST_MESSAGE_TIMESTAMP,
    max(END_TIMESTAMP) as LAST_MESSAGE_TIMESTAMP,
    argMaxState(USER_ID, START_TIMESTAMP) as USER_ID_STATE,
    argMaxState(SESSION_ID, START_TIMESTAMP) as SESSION_ID_STATE,
    argMaxState(DEVICE, START_TIMESTAMP) as DEVICE_STATE,
    argMaxState(OS, START_TIMESTAMP) as OS_STATE,
    argMaxState(BROWSER, START_TIMESTAMP) as BROWSER_STATE,
    argMaxState(LOCALE, START_TIMESTAMP) as LOCALE_STATE,
    argMaxState(LOCATION, START_TIMESTAMP) as LOCATION_STATE,
    argMaxState(CHANNEL_ID, START_TIMESTAMP) as CHANNEL_ID_STATE,
    
    -- Conversation metrics
    countState() as DIALOGUE_VOLUME_STATE,
    
    -- Time metrics
    minState(START_TIMESTAMP) as MIN_START_TIMESTAMP_STATE,
    maxState(END_TIMESTAMP) as MAX_END_TIMESTAMP_STATE,
    
    -- Content metrics
    sumState(NUM_WORDS_PROMPT) as NUM_WORDS_PROMPT_TOTAL_STATE,
    avgState(NUM_WORDS_PROMPT) as NUM_WORDS_PROMPT_AVG_STATE,
    minState(NUM_WORDS_PROMPT) as NUM_WORDS_PROMPT_MIN_STATE,
    maxState(NUM_WORDS_PROMPT) as NUM_WORDS_PROMPT_MAX_STATE,
    
    sumState(NUM_WORDS_RESPONSE) as NUM_WORDS_RESPONSE_TOTAL_STATE,
    avgState(NUM_WORDS_RESPONSE) as NUM_WORDS_RESPONSE_AVG_STATE,
    minState(NUM_WORDS_RESPONSE) as NUM_WORDS_RESPONSE_MIN_STATE,
    maxState(NUM_WORDS_RESPONSE) as NUM_WORDS_RESPONSE_MAX_STATE,
    
    -- Latency metrics
    sumState(LATENCY) as TIME_LATENCY_SUM_STATE,
    avgState(LATENCY) as TIME_LATENCY_AVG_STATE,
    minState(LATENCY) as TIME_LATENCY_MIN_STATE,
    maxState(LATENCY) as TIME_LATENCY_MAX_STATE,
    
    -- Token metrics
    sumState(TOKENS_SPENT_PROMPT) as TOKENS_SPENT_PROMPT_TOTAL_STATE,
    avgState(TOKENS_SPENT_PROMPT) as TOKENS_SPENT_PROMPT_AVG_STATE,
    minState(TOKENS_SPENT_PROMPT) as TOKENS_SPENT_PROMPT_MIN_STATE,
    maxState(TOKENS_SPENT_PROMPT) as TOKENS_SPENT_PROMPT_MAX_STATE,
    
    sumState(TOKENS_SPENT_RESPONSE) as TOKENS_SPENT_RESPONSE_TOTAL_STATE,
    avgState(TOKENS_SPENT_RESPONSE) as TOKENS_SPENT_RESPONSE_AVG_STATE,
    minState(TOKENS_SPENT_RESPONSE) as TOKENS_SPENT_RESPONSE_MIN_STATE,
    maxState(TOKENS_SPENT_RESPONSE) as TOKENS_SPENT_RESPONSE_MAX_STATE,
    
    -- Cost calculation
    sumState(TOKENS_SPENT_PROMPT * a.inputCost + TOKENS_SPENT_RESPONSE * a.outputCost) as COST_TOTAL_STATE,
    avgState(TOKENS_SPENT_PROMPT * a.inputCost + TOKENS_SPENT_RESPONSE * a.outputCost) as COST_AVG_STATE,
    minState(TOKENS_SPENT_PROMPT * a.inputCost + TOKENS_SPENT_RESPONSE * a.outputCost) as COST_MIN_STATE,
    maxState(TOKENS_SPENT_PROMPT * a.inputCost + TOKENS_SPENT_RESPONSE * a.outputCost) as COST_MAX_STATE,
    
    -- Language metrics
    groupUniqArrayState(LANG_PROMPT) as LANG_PROMPT_STATE,
    groupUniqArrayState(LANG_RESPONSE) as LANG_RESPONSE_STATE,
    
    -- Sentiment metrics
    groupUniqArrayState(SENTIMENT_PROMPT) as SENTIMENT_PROMPT_STATE,
    groupUniqArrayState(SENTIMENT_RESPONSE) as SENTIMENT_RESPONSE_STATE,
    maxState(SENTIMENT_PROMPT_POSITIVE) as SENTIMENT_PROMPT_POSITIVE_MAX_STATE,
    maxState(SENTIMENT_PROMPT_NEGATIVE) as SENTIMENT_PROMPT_NEGATIVE_MAX_STATE,
    maxState(SENTIMENT_PROMPT_NEUTRAL) as SENTIMENT_PROMPT_NEUTRAL_MAX_STATE,
    maxState(SENTIMENT_RESPONSE_POSITIVE) as SENTIMENT_RESPONSE_POSITIVE_MAX_STATE,
    maxState(SENTIMENT_RESPONSE_NEGATIVE) as SENTIMENT_RESPONSE_NEGATIVE_MAX_STATE,
    maxState(SENTIMENT_RESPONSE_NEUTRAL) as SENTIMENT_RESPONSE_NEUTRAL_MAX_STATE,
    
    -- Readability metrics
    avgState(READABILITY_RESPONSE) as READABILITY_RESPONSE_AVG_STATE,
    
    -- Security metrics
    maxState(MALICIOUS_PROMPT) as MALICIOUS_PROMPT_STATE,
    groupArrayState(MALICIOUS_PROMPT_SCORE) as MALICIOUS_PROMPT_SCORE_STATE,
    
    -- PII metrics
    maxState(PII_PROMPT) as PII_PROMPT_STATE,
    maxState(PII_RESPONSE) as PII_RESPONSE_STATE,
    
    -- Classification
    argMaxState(PURPOSE_LABEL, START_TIMESTAMP) as PURPOSE_LABEL_STATE,
    
    -- Sample content (first message)
    argMinState(INPUT, START_TIMESTAMP) as FIRST_INPUT_STATE,
    argMinState(OUTPUT, START_TIMESTAMP) as FIRST_OUTPUT_STATE
FROM traces_processed tp
JOIN apps a ON tp.APP_ID = a.id
WHERE TASK = 'message'
GROUP BY APP_ID, CONVERSATION_ID, toDate(START_TIMESTAMP / 1000), toStartOfDay(START_TIME);


-- Create a view to read from the materialized view
CREATE OR REPLACE VIEW traces_conversations_view AS
SELECT
    APP_ID,
    CONVERSATION_ID,
    -- Use minMerge and maxMerge to get the true first and last timestamps
    minMerge(MIN_START_TIMESTAMP_STATE) as FIRST_MESSAGE_TIMESTAMP,
    maxMerge(MAX_END_TIMESTAMP_STATE) as LAST_MESSAGE_TIMESTAMP,
    argMaxMerge(USER_ID_STATE) as USER_ID,
    argMaxMerge(SESSION_ID_STATE) as SESSION_ID,
    argMaxMerge(DEVICE_STATE) as DEVICE,
    argMaxMerge(OS_STATE) as OS,
    argMaxMerge(BROWSER_STATE) as BROWSER,
    argMaxMerge(LOCALE_STATE) as LOCALE,
    argMaxMerge(LOCATION_STATE) as LOCATION,
    argMaxMerge(CHANNEL_ID_STATE) as CHANNEL_ID,
    
    -- Conversation metrics
    countMerge(DIALOGUE_VOLUME_STATE) as DIALOGUE_VOLUME,
    if(countMerge(DIALOGUE_VOLUME_STATE) = 1, 1, 0) as ONE_INTERACTION,
    
    -- Time metrics - calculate directly from the timestamps
    (maxMerge(MAX_END_TIMESTAMP_STATE) - minMerge(MIN_START_TIMESTAMP_STATE))/1000 as TIME_TOTAL,
    if(countMerge(DIALOGUE_VOLUME_STATE) > 1, 
       ((maxMerge(MAX_END_TIMESTAMP_STATE) - minMerge(MIN_START_TIMESTAMP_STATE))/1000)/(countMerge(DIALOGUE_VOLUME_STATE)-1), 
       0) as TIME_BETWEEN_INTERACTIONS,
    
    -- Content metrics
    sumMerge(NUM_WORDS_PROMPT_TOTAL_STATE) as NUM_WORDS_PROMPT_TOTAL,
    avgMerge(NUM_WORDS_PROMPT_AVG_STATE) as NUM_WORDS_PROMPT_AVG,
    minMerge(NUM_WORDS_PROMPT_MIN_STATE) as NUM_WORDS_PROMPT_MIN,
    maxMerge(NUM_WORDS_PROMPT_MAX_STATE) as NUM_WORDS_PROMPT_MAX,
    
    sumMerge(NUM_WORDS_RESPONSE_TOTAL_STATE) as NUM_WORDS_RESPONSE_TOTAL,
    avgMerge(NUM_WORDS_RESPONSE_AVG_STATE) as NUM_WORDS_RESPONSE_AVG,
    minMerge(NUM_WORDS_RESPONSE_MIN_STATE) as NUM_WORDS_RESPONSE_MIN,
    maxMerge(NUM_WORDS_RESPONSE_MAX_STATE) as NUM_WORDS_RESPONSE_MAX,
    
    -- Latency metrics
    sumMerge(TIME_LATENCY_SUM_STATE) as TIME_LATENCY_SUM,
    avgMerge(TIME_LATENCY_AVG_STATE) as TIME_LATENCY_AVG,
    minMerge(TIME_LATENCY_MIN_STATE) as TIME_LATENCY_MIN,
    maxMerge(TIME_LATENCY_MAX_STATE) as TIME_LATENCY_MAX,
    
    -- Token metrics
    sumMerge(TOKENS_SPENT_PROMPT_TOTAL_STATE) as TOKENS_SPENT_PROMPT_TOTAL,
    avgMerge(TOKENS_SPENT_PROMPT_AVG_STATE) as TOKENS_SPENT_PROMPT_AVG,
    minMerge(TOKENS_SPENT_PROMPT_MIN_STATE) as TOKENS_SPENT_PROMPT_MIN,
    maxMerge(TOKENS_SPENT_PROMPT_MAX_STATE) as TOKENS_SPENT_PROMPT_MAX,
    
    sumMerge(TOKENS_SPENT_RESPONSE_TOTAL_STATE) as TOKENS_SPENT_RESPONSE_TOTAL,
    avgMerge(TOKENS_SPENT_RESPONSE_AVG_STATE) as TOKENS_SPENT_RESPONSE_AVG,
    minMerge(TOKENS_SPENT_RESPONSE_MIN_STATE) as TOKENS_SPENT_RESPONSE_MIN,
    maxMerge(TOKENS_SPENT_RESPONSE_MAX_STATE) as TOKENS_SPENT_RESPONSE_MAX,
    
    -- Cost metrics
    sumMerge(COST_TOTAL_STATE) as COST_TOTAL,
    avgMerge(COST_AVG_STATE) as COST_AVG,
    minMerge(COST_MIN_STATE) as COST_MIN,
    maxMerge(COST_MAX_STATE) as COST_MAX,
    
    -- Language metrics
    groupUniqArrayMerge(LANG_PROMPT_STATE) as LANG_PROMPT,
    groupUniqArrayMerge(LANG_RESPONSE_STATE) as LANG_RESPONSE,
    
    -- Sentiment metrics
    groupUniqArrayMerge(SENTIMENT_PROMPT_STATE) as SENTIMENT_PROMPT,
    groupUniqArrayMerge(SENTIMENT_RESPONSE_STATE) as SENTIMENT_RESPONSE,
    maxMerge(SENTIMENT_PROMPT_POSITIVE_MAX_STATE) as SENTIMENT_PROMPT_POSITIVE_MAX,
    maxMerge(SENTIMENT_PROMPT_NEGATIVE_MAX_STATE) as SENTIMENT_PROMPT_NEGATIVE_MAX,
    maxMerge(SENTIMENT_PROMPT_NEUTRAL_MAX_STATE) as SENTIMENT_PROMPT_NEUTRAL_MAX,
    maxMerge(SENTIMENT_RESPONSE_POSITIVE_MAX_STATE) as SENTIMENT_RESPONSE_POSITIVE_MAX,
    maxMerge(SENTIMENT_RESPONSE_NEGATIVE_MAX_STATE) as SENTIMENT_RESPONSE_NEGATIVE_MAX,
    maxMerge(SENTIMENT_RESPONSE_NEUTRAL_MAX_STATE) as SENTIMENT_RESPONSE_NEUTRAL_MAX,
    
    -- Readability metrics
    avgMerge(READABILITY_RESPONSE_AVG_STATE) as READABILITY_RESPONSE,
    
    -- Security metrics
    maxMerge(MALICIOUS_PROMPT_STATE) as MALICIOUS_PROMPT,
    groupArrayMerge(MALICIOUS_PROMPT_SCORE_STATE) as MALICIOUS_PROMPT_SCORE,
    
    -- PII metrics
    maxMerge(PII_PROMPT_STATE) as PII_PROMPT,
    maxMerge(PII_RESPONSE_STATE) as PII_RESPONSE,
    
    -- Classification
    argMaxMerge(PURPOSE_LABEL_STATE) as PURPOSE_LABEL,
    
    -- Sample content
    argMinMerge(FIRST_INPUT_STATE) as FIRST_INPUT,
    argMinMerge(FIRST_OUTPUT_STATE) as FIRST_OUTPUT,
    
    -- Add timestamp fields converted to DateTime for easier querying
    fromUnixTimestamp64Milli(minMerge(MIN_START_TIMESTAMP_STATE)) as FIRST_MESSAGE_TIME,
    fromUnixTimestamp64Milli(maxMerge(MAX_END_TIMESTAMP_STATE)) as LAST_MESSAGE_TIME
FROM traces_conversations
GROUP BY APP_ID, CONVERSATION_ID;

-- Create a view for classifier analysis with simpler JSON parsing
CREATE OR REPLACE VIEW classifier_analysis AS
SELECT
    APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CLASSIFIER_ID,
    CATEGORY_ID,
    LABEL_ID,
    SCORE,
    count() AS count
FROM (
    SELECT
        APP_ID,
        EVENT_DATE,
        START_TIME,
        JSONExtractInt(json, 'ID') AS CLASSIFIER_ID,
        JSONExtractString(json, 'CATEGORY') AS CATEGORY_ID,
        JSONExtractString(label) AS LABEL_ID,  -- Extract string value here
        JSONExtractInt(json, 'SCORE') AS SCORE
    FROM traces_processed
    ARRAY JOIN JSONExtractArrayRaw(OUTPUT_CLASSIFIERS) AS json
    ARRAY JOIN JSONExtractArrayRaw(json, 'LABEL') AS label
    WHERE OUTPUT_CLASSIFIERS IS NOT NULL AND OUTPUT_CLASSIFIERS != ''
)
GROUP BY APP_ID, EVENT_DATE, day, CLASSIFIER_ID, CATEGORY_ID, LABEL_ID, SCORE;

-- Create a materialized view for daily classifier KPIs
CREATE MATERIALIZED VIEW IF NOT EXISTS kpi_topics_1d
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(day)
ORDER BY (day, APP_ID, CLASSIFIER_ID, CATEGORY_ID, LABEL_ID)
AS SELECT
    toDate(toStartOfDay(START_TIME)) AS day,
    APP_ID,
    CLASSIFIER_ID,
    CATEGORY_ID,
    LABEL_ID,
    SCORE,
    
    -- Conversation and message counts
    uniqState(CONVERSATION_ID) AS conversations_count_state,
    uniqState(INTERACTION_ID) AS messages_count_state,
    
    -- Sentiment metrics
    sumState(SENTIMENT_PROMPT_POSITIVE) AS sentiment_prompt_positive_state,
    sumState(SENTIMENT_PROMPT_NEGATIVE) AS sentiment_prompt_negative_state,
    sumState(SENTIMENT_RESPONSE_POSITIVE) AS sentiment_response_positive_state,
    sumState(SENTIMENT_RESPONSE_NEGATIVE) AS sentiment_response_negative_state,
    
    -- Language metrics
    countState(LANG_PROMPT) AS lang_prompt_count_state,
    countState(LANG_RESPONSE) AS lang_response_count_state,
    
    -- PII metrics
    sumState(PII_PROMPT) AS pii_prompt_state,
    sumState(PII_RESPONSE) AS pii_response_state,
    
    -- Malicious content metrics
    sumState(MALICIOUS_PROMPT) AS malicious_prompt_state,
    
    -- Word count metrics
    sumState(NUM_WORDS_PROMPT) AS num_words_prompt_state,
    sumState(NUM_WORDS_RESPONSE) AS num_words_response_state,
    
    -- Token metrics
    sumState(TOKENS_SPENT_PROMPT) AS tokens_spent_prompt_state,
    sumState(TOKENS_SPENT_RESPONSE) AS tokens_spent_response_state,
    
    -- Readability metrics
    avgState(READABILITY_RESPONSE) AS readability_response_state,
    
    -- Cost metrics - store tokens for later calculation with app costs
    sumState(TOKENS_SPENT_PROMPT) AS cost_prompt_state,
    sumState(TOKENS_SPENT_RESPONSE) AS cost_response_state,
    
    -- Time metrics
    maxState(time_diff) AS time_total_state,
    sumState(LATENCY) AS time_latency_state,
    
    -- Dialogue time metrics
    minState(START_TIME) AS min_start_time_state,
    maxState(END_TIMESTAMP) AS max_end_time_state,
    uniqState(INTERACTION_ID) AS dialogue_volume_state,
    
    -- Feedback metrics
    countStateIf(1, FEEDBACK_TAG = 'positive') as feedback_positive_count_state,
    countStateIf(1, FEEDBACK_TAG = 'negative') as feedback_negative_count_state
FROM (
    SELECT
        APP_ID,
        START_TIME,
        END_TIMESTAMP,
        CONVERSATION_ID,
        INTERACTION_ID,
        SENTIMENT_PROMPT_POSITIVE,
        SENTIMENT_PROMPT_NEGATIVE,
        SENTIMENT_PROMPT_NEUTRAL,
        SENTIMENT_RESPONSE_POSITIVE,
        SENTIMENT_RESPONSE_NEGATIVE,
        SENTIMENT_RESPONSE_NEUTRAL,
        LANG_PROMPT,
        LANG_RESPONSE,
        PII_PROMPT,
        PII_RESPONSE,
        MALICIOUS_PROMPT,
        NUM_WORDS_PROMPT,
        NUM_WORDS_RESPONSE,
        TOKENS_SPENT_PROMPT,
        TOKENS_SPENT_RESPONSE,
        READABILITY_RESPONSE,
        LATENCY,
        FEEDBACK_TAG,
        JSONExtractInt(json, 'ID') AS CLASSIFIER_ID,
        JSONExtractString(json, 'CATEGORY') AS CATEGORY_ID,
        JSONExtractString(label) AS LABEL_ID,
        JSONExtractInt(json, 'SCORE') AS SCORE,
        toInt64(END_TIMESTAMP) - toInt64(START_TIME) AS time_diff
    FROM traces_processed
    ARRAY JOIN JSONExtractArrayRaw(OUTPUT_CLASSIFIERS) AS json
    ARRAY JOIN JSONExtractArrayRaw(json, 'LABEL') AS label
    WHERE OUTPUT_CLASSIFIERS IS NOT NULL AND OUTPUT_CLASSIFIERS != '' AND TASK = 'message'
)
GROUP BY day, APP_ID, CLASSIFIER_ID, CATEGORY_ID, LABEL_ID, SCORE;

-- Create a view for querying the aggregated data with app costs
CREATE OR REPLACE VIEW kpi_topics_1d_view AS
SELECT
    k.day,
    k.APP_ID,
    k.CLASSIFIER_ID,
    k.CATEGORY_ID,
    k.LABEL_ID,
    
    -- Cost calculation using app costs (default to 0 if NULL)
    sumMerge(k.cost_prompt_state) * if(a.inputCost IS NULL, 0, a.inputCost) + 
    sumMerge(k.cost_response_state) * if(a.outputCost IS NULL, 0, a.outputCost) AS COST,
    
    -- Conversation and message counts
    uniqMerge(k.conversations_count_state) AS CONVERSATIONS,
    uniqMerge(k.messages_count_state) AS MESSAGES,
    uniqMerge(k.messages_count_state) / uniqMerge(k.conversations_count_state) AS DIALOGUE_VOLUME,
    
    -- Sentiment percentages - with default values of 0 instead of NULL
    if(isNull(100.0 * sumMerge(k.sentiment_prompt_positive_state) / 
        nullIf(sumMerge(k.sentiment_prompt_positive_state) + sumMerge(k.sentiment_prompt_negative_state), 0)),
        0,
        100.0 * sumMerge(k.sentiment_prompt_positive_state) / 
        nullIf(sumMerge(k.sentiment_prompt_positive_state) + sumMerge(k.sentiment_prompt_negative_state), 0)) AS SENTIMENT_PROMPT_POSITIVE,
    
    if(isNull(100.0 * sumMerge(k.sentiment_prompt_negative_state) / 
        nullIf(sumMerge(k.sentiment_prompt_positive_state) + sumMerge(k.sentiment_prompt_negative_state), 0)),
        0,
        100.0 * sumMerge(k.sentiment_prompt_negative_state) / 
        nullIf(sumMerge(k.sentiment_prompt_positive_state) + sumMerge(k.sentiment_prompt_negative_state), 0)) AS SENTIMENT_PROMPT_NEGATIVE,
    
    if(isNull(100.0 * sumMerge(k.sentiment_response_positive_state) / 
        nullIf(sumMerge(k.sentiment_response_positive_state) + sumMerge(k.sentiment_response_negative_state), 0)),
        0,
        100.0 * sumMerge(k.sentiment_response_positive_state) / 
        nullIf(sumMerge(k.sentiment_response_positive_state) + sumMerge(k.sentiment_response_negative_state), 0)) AS SENTIMENT_RESPONSE_POSITIVE,
    
    if(isNull(100.0 * sumMerge(k.sentiment_response_negative_state) / 
        nullIf(sumMerge(k.sentiment_response_positive_state) + sumMerge(k.sentiment_response_negative_state), 0)),
        0,
        100.0 * sumMerge(k.sentiment_response_negative_state) / 
        nullIf(sumMerge(k.sentiment_response_positive_state) + sumMerge(k.sentiment_response_negative_state), 0)) AS SENTIMENT_RESPONSE_NEGATIVE,
    
    -- Sentiment rate metrics (percentage of messages with positive/negative sentiment)
    100.0 * sumMerge(k.sentiment_prompt_positive_state) / uniqMerge(k.messages_count_state) as SENTIMENT_PROMPT_POSITIVE_RATE,
    100.0 * sumMerge(k.sentiment_prompt_negative_state) / uniqMerge(k.messages_count_state) as SENTIMENT_PROMPT_NEGATIVE_RATE,
    100.0 * sumMerge(k.sentiment_response_positive_state) / uniqMerge(k.messages_count_state) as SENTIMENT_RESPONSE_POSITIVE_RATE,
    100.0 * sumMerge(k.sentiment_response_negative_state) / uniqMerge(k.messages_count_state) as SENTIMENT_RESPONSE_NEGATIVE_RATE,
    
    -- Language metrics
    countMerge(k.lang_prompt_count_state) AS LANG_PROMPT,
    countMerge(k.lang_response_count_state) AS LANG_RESPONSE,
    
    -- PII metrics
    sumMerge(k.pii_prompt_state) AS PII_PROMPT,
    sumMerge(k.pii_response_state) AS PII_RESPONSE,
    
    -- Malicious content metrics
    sumMerge(k.malicious_prompt_state) AS MALICIOUS_PROMPT,
    
    -- Word count metrics
    sumMerge(k.num_words_prompt_state) AS NUM_WORDS_PROMPT,
    sumMerge(k.num_words_response_state) AS NUM_WORDS_RESPONSE,
    
    -- Token metrics
    sumMerge(k.tokens_spent_prompt_state) AS TOKENS_SPENT_PROMPT,
    sumMerge(k.tokens_spent_response_state) AS TOKENS_SPENT_RESPONSE,
    
    -- Readability metrics
    avgMerge(k.readability_response_state) AS READABILITY_RESPONSE,
    
    -- Time metrics
    maxMerge(k.time_total_state) AS TIME_TOTAL,
    sumMerge(k.time_latency_state) AS TIME_LATENCY,
    
    -- Dialogue time metrics - using simpler calculation
    if(uniqMerge(k.dialogue_volume_state) > 1,
        maxMerge(k.time_total_state) / (uniqMerge(k.dialogue_volume_state) - 1), 
        0) AS TIME_BETWEEN_INTERACTIONS,
    
    -- Feedback metrics
    countMerge(k.feedback_positive_count_state) as FEEDBACK_POSITIVE,
    countMerge(k.feedback_negative_count_state) as FEEDBACK_NEGATIVE,
    100.0 * countMerge(k.feedback_positive_count_state) / uniqMerge(k.messages_count_state) as FEEDBACK_POSITIVE_RATE,
    100.0 * countMerge(k.feedback_negative_count_state) / uniqMerge(k.messages_count_state) as FEEDBACK_NEGATIVE_RATE
FROM kpi_topics_1d k
LEFT JOIN apps a ON k.APP_ID = a.id
GROUP BY k.day, k.APP_ID, k.CLASSIFIER_ID, k.CATEGORY_ID, k.LABEL_ID, a.inputCost, a.outputCost;
