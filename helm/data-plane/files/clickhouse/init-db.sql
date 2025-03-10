-- Create the database
CREATE DATABASE IF NOT EXISTS neuraltrust ON CLUSTER default;

-- Switch to the database
USE neuraltrust;

-- Teams table
CREATE TABLE IF NOT EXISTS teams_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS teams ON CLUSTER default AS teams_local
ENGINE = Distributed('default', neuraltrust, teams_local, rand());

-- Apps table
CREATE TABLE IF NOT EXISTS apps_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS apps ON CLUSTER default AS apps_local
ENGINE = Distributed('default', neuraltrust, apps_local, rand());

-- Classifiers table
CREATE TABLE IF NOT EXISTS classifiers_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS classifiers ON CLUSTER default AS classifiers_local
ENGINE = Distributed('default', neuraltrust, classifiers_local, rand());

-- Classes table
CREATE TABLE IF NOT EXISTS classes_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS classes ON CLUSTER default AS classes_local
ENGINE = Distributed('default', neuraltrust, classes_local, rand());

-- Raw traces table
CREATE TABLE IF NOT EXISTS traces_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS traces ON CLUSTER default AS traces_local
ENGINE = Distributed('default', neuraltrust, traces_local, rand());

-- Processed traces table with KPIs
CREATE TABLE IF NOT EXISTS traces_processed_local ON CLUSTER default
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
CREATE TABLE IF NOT EXISTS traces_processed ON CLUSTER default AS traces_processed_local
ENGINE = Distributed('default', neuraltrust, traces_processed_local, rand());

-- Daily metrics for UI graphs (main materialized view)
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_usage_metrics_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_usage_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID AS APP_ID,
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
    avgState(LATENCY) as avg_latency_state,
    -- Sentiment metrics
    sumState(SENTIMENT_PROMPT_POSITIVE) as sentiment_prompt_positive_state,
    sumState(SENTIMENT_PROMPT_NEGATIVE) as sentiment_prompt_negative_state,
    sumState(SENTIMENT_PROMPT_NEUTRAL) as sentiment_prompt_neutral_state,
    sumState(SENTIMENT_RESPONSE_POSITIVE) as sentiment_response_positive_state,
    sumState(SENTIMENT_RESPONSE_NEGATIVE) as sentiment_response_negative_state,
    sumState(SENTIMENT_RESPONSE_NEUTRAL) as sentiment_response_neutral_state
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
        SENTIMENT_PROMPT_POSITIVE,
        SENTIMENT_PROMPT_NEGATIVE,
        SENTIMENT_PROMPT_NEUTRAL,
        SENTIMENT_RESPONSE_POSITIVE,
        SENTIMENT_RESPONSE_NEGATIVE,
        SENTIMENT_RESPONSE_NEUTRAL,
        EVENT_DATE,
        -- Count messages per conversation
        count() OVER (PARTITION BY APP_ID, CONVERSATION_ID) as conv_message_count
    FROM traces_processed_local
    WHERE TASK = 'message'
)
GROUP BY APP_ID, EVENT_DATE, day;

-- Create a Distributed table for usage metrics
CREATE TABLE IF NOT EXISTS traces_usage_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_usage_metrics_local, rand());

-- Language metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_language_metrics_local ON CLUSTER default
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_language_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, LANG_PROMPT, day)
AS SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    LANG_PROMPT,
    count() as language_count
FROM traces_processed_local
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, day, LANG_PROMPT;

-- Create a Distributed table for language metrics
CREATE TABLE IF NOT EXISTS traces_language_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_language_metrics_local, rand());

-- Create a view to calculate conversation message counts
CREATE VIEW IF NOT EXISTS conversation_message_counts_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CONVERSATION_ID,
    count() as message_count
FROM traces_processed_local
WHERE TASK = 'message'
GROUP BY APP_ID, EVENT_DATE, day, CONVERSATION_ID;

-- Create a Distributed view for conversation message counts
CREATE TABLE IF NOT EXISTS conversation_message_counts ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, conversation_message_counts_local, rand());

-- Create a view to calculate single message rate
CREATE VIEW IF NOT EXISTS single_message_rate_view_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    day,
    countIf(message_count = 1) as single_message_conversations,
    count() as total_conversations,
    100.0 * countIf(message_count = 1) / count() as single_message_rate
FROM conversation_message_counts_local
GROUP BY APP_ID, EVENT_DATE, day;

-- Create a Distributed view for single message rate
CREATE TABLE IF NOT EXISTS single_message_rate_view ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, single_message_rate_view_local, rand());

-- Add the traces_usage_metrics_view to get merged results
CREATE VIEW IF NOT EXISTS traces_usage_metrics_view_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    day,
    -- Message metrics
    countMerge(messages_count_state) as messages_count,
    uniqMerge(conversations_count_state) as conversations_count,
    maxMerge(max_end_timestamp_state) as max_end_timestamp,
    minMerge(min_start_timestamp_state) as min_start_timestamp,
    uniqMerge(single_message_conv_state) as single_message_conversations,
    avgMerge(avg_prompt_words_state) as avg_prompt_words,
    avgMerge(avg_response_words_state) as avg_response_words,
    
    -- Token metrics
    sumMerge(prompt_tokens_state) as prompt_tokens,
    sumMerge(response_tokens_state) as response_tokens,
    avgMerge(avg_latency_state) as avg_latency,
    
    -- Sentiment metrics
    sumMerge(sentiment_prompt_positive_state) as sentiment_prompt_positive,
    sumMerge(sentiment_prompt_negative_state) as sentiment_prompt_negative,
    sumMerge(sentiment_prompt_neutral_state) as sentiment_prompt_neutral,
    sumMerge(sentiment_response_positive_state) as sentiment_response_positive,
    sumMerge(sentiment_response_negative_state) as sentiment_response_negative,
    sumMerge(sentiment_response_neutral_state) as sentiment_response_neutral,
    
    -- Derived metrics
    if(uniqMerge(conversations_count_state) > 0, 
       uniqMerge(single_message_conv_state) / uniqMerge(conversations_count_state), 
       0) as single_message_rate,
    sumMerge(prompt_tokens_state) + sumMerge(response_tokens_state) as total_tokens,
    (sumMerge(prompt_tokens_state) + sumMerge(response_tokens_state)) * 0.01 / 1000 as estimated_cost
FROM traces_usage_metrics_local
GROUP BY APP_ID, EVENT_DATE, day;

-- Create a Distributed view for usage metrics view
CREATE TABLE IF NOT EXISTS traces_usage_metrics_view ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_usage_metrics_view_local, rand());

-- User and session metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_user_metrics_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_user_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID AS APP_ID,
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
GROUP BY APP_ID, EVENT_DATE, day;

-- Create a Distributed table for user metrics
CREATE TABLE IF NOT EXISTS traces_user_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_user_metrics_local, rand());

-- Update the metrics view to include sentiment metrics
CREATE OR REPLACE VIEW traces_metrics_local ON CLUSTER default AS
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
    groupArrayMerge(u.countries_state) as countries,
    -- Sentiment metrics
    sumMerge(m.sentiment_prompt_positive_state) as sentiment_prompt_positive,
    sumMerge(m.sentiment_prompt_negative_state) as sentiment_prompt_negative,
    sumMerge(m.sentiment_prompt_neutral_state) as sentiment_prompt_neutral,
    sumMerge(m.sentiment_response_positive_state) as sentiment_response_positive,
    sumMerge(m.sentiment_response_negative_state) as sentiment_response_negative,
    sumMerge(m.sentiment_response_neutral_state) as sentiment_response_neutral
FROM traces_usage_metrics_local m
LEFT JOIN single_message_rate_view_local s ON m.APP_ID = s.APP_ID AND m.EVENT_DATE = s.EVENT_DATE AND m.day = s.day
LEFT JOIN traces_user_metrics_local u ON m.APP_ID = u.APP_ID AND m.EVENT_DATE = u.EVENT_DATE AND m.day = u.day
LEFT JOIN apps_local a ON m.APP_ID = a.id
GROUP BY m.APP_ID, m.EVENT_DATE, m.day, s.single_message_rate, a.inputCost, a.outputCost;

-- Create a Distributed view for metrics
CREATE TABLE IF NOT EXISTS traces_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_metrics_local, rand());

-- Create a view for country metrics
CREATE OR REPLACE VIEW traces_country_metrics_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    LOCATION as country,
    count() as count
FROM traces_processed_local
WHERE TASK = 'message' AND LOCATION != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), LOCATION
ORDER BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), count DESC;

-- Create a Distributed view for country metrics
CREATE TABLE IF NOT EXISTS traces_country_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_country_metrics_local, rand());

-- Update the total metrics view to include user and session metrics
CREATE OR REPLACE VIEW traces_metrics_total_local ON CLUSTER default AS
SELECT 
    m.APP_ID AS APP_ID,
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
FROM traces_metrics_local m
GROUP BY m.APP_ID;

-- Create a Distributed view for total metrics
CREATE TABLE IF NOT EXISTS traces_metrics_total ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_metrics_total_local, rand());

-- Separate language metrics view
CREATE VIEW IF NOT EXISTS traces_language_daily_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    day,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics_local
GROUP BY APP_ID, EVENT_DATE, day, LANG_PROMPT
ORDER BY APP_ID, EVENT_DATE, day, count DESC;

-- Create a Distributed view for daily language metrics
CREATE TABLE IF NOT EXISTS traces_language_daily ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_language_daily_local, rand());

-- Total language metrics view
CREATE VIEW IF NOT EXISTS traces_language_total_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    LANG_PROMPT as language,
    sum(language_count) as count
FROM traces_language_metrics_local
GROUP BY APP_ID, LANG_PROMPT
ORDER BY APP_ID, count DESC;

-- Create a Distributed view for total language metrics
CREATE TABLE IF NOT EXISTS traces_language_total ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_language_total_local, rand());

-- Device metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_device_metrics_local ON CLUSTER default
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_device_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, DEVICE)
AS SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    DEVICE,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND DEVICE != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), DEVICE;

-- Create a Distributed view for device metrics
CREATE TABLE IF NOT EXISTS traces_device_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_device_metrics_local, rand());

-- Browser metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_browser_metrics_local ON CLUSTER default
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_browser_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, BROWSER)
AS SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    BROWSER,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND BROWSER != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), BROWSER;

-- Create a Distributed view for browser metrics
CREATE TABLE IF NOT EXISTS traces_browser_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_browser_metrics_local, rand());

-- OS metrics view
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_os_metrics_local ON CLUSTER default
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_os_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, OS)
AS SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    OS,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND OS != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), OS;

-- Create a Distributed view for OS metrics
CREATE TABLE IF NOT EXISTS traces_os_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_os_metrics_local, rand());

-- Create a materialized view for sessions by channel
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_channel_metrics_local ON CLUSTER default
ENGINE = ReplicatedSummingMergeTree('/clickhouse/tables/{shard}/traces_channel_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, channel)
AS
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    CHANNEL_ID as channel,
    count(DISTINCT SESSION_ID) as count
FROM traces_processed_local
WHERE TASK = 'message' AND CHANNEL_ID IS NOT NULL
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), CHANNEL_ID;

-- Create a Distributed view for channel metrics
CREATE TABLE IF NOT EXISTS traces_channel_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_channel_metrics_local, rand());

-- User engagement metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_engagement_metrics_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_engagement_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID AS APP_ID,
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
CREATE TABLE IF NOT EXISTS traces_engagement_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_engagement_metrics_local, rand());

-- Top users by requests view with AggregatingMergeTree engine
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_top_users_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_top_users', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day, USER_ID)
AS 
SELECT
    APP_ID AS APP_ID,
    EVENT_DATE,
    toStartOfDay(START_TIME) as day,
    USER_ID,
    countState() as request_count_state
FROM traces_processed_local
WHERE TASK = 'message' AND USER_ID != ''
GROUP BY APP_ID, EVENT_DATE, toStartOfDay(START_TIME), USER_ID;

-- Create a Distributed view for top users
CREATE TABLE IF NOT EXISTS traces_top_users ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_top_users_local, rand());

-- Security metrics view with AggregatingMergeTree
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_security_metrics_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_security_metrics', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (EVENT_DATE, APP_ID, day)
AS SELECT
    APP_ID AS APP_ID,
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

-- Create a Distributed table for security metrics
CREATE TABLE IF NOT EXISTS traces_security_metrics ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_security_metrics_local, rand());

-- Create a materialized view with its own storage engine for conversation aggregation
CREATE MATERIALIZED VIEW IF NOT EXISTS traces_conversations_local ON CLUSTER default
ENGINE = ReplicatedAggregatingMergeTree('/clickhouse/tables/{shard}/traces_conversations', '{replica}')
PARTITION BY toYYYYMM(EVENT_DATE)
ORDER BY (APP_ID, CONVERSATION_ID)
AS SELECT
    APP_ID AS APP_ID,
    CONVERSATION_ID,
    toDate(START_TIMESTAMP / 1000) as EVENT_DATE,
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
    avgState(READABILITY_PROMPT) as READABILITY_PROMPT_AVG_STATE,
    minState(READABILITY_PROMPT) as READABILITY_PROMPT_MIN_STATE,
    maxState(READABILITY_PROMPT) as READABILITY_PROMPT_MAX_STATE,
    avgState(READABILITY_RESPONSE) as READABILITY_RESPONSE_AVG_STATE,
    minState(READABILITY_RESPONSE) as READABILITY_RESPONSE_MIN_STATE,
    maxState(READABILITY_RESPONSE) as READABILITY_RESPONSE_MAX_STATE,
    
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
FROM traces_processed_local tp
JOIN apps_local a ON tp.APP_ID = a.id
WHERE TASK = 'message'
GROUP BY APP_ID, CONVERSATION_ID, toDate(START_TIMESTAMP / 1000);

-- Create a Distributed table for conversations
CREATE TABLE IF NOT EXISTS traces_conversations ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_conversations_local, rand());

-- Create a view to read from the materialized view
CREATE VIEW IF NOT EXISTS traces_conversations_view_local ON CLUSTER default AS
SELECT
    APP_ID AS APP_ID,
    CONVERSATION_ID,
    FIRST_MESSAGE_TIMESTAMP,
    LAST_MESSAGE_TIMESTAMP,
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
    
    -- Time metrics
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
    avgMerge(READABILITY_PROMPT_AVG_STATE) as READABILITY_PROMPT_AVG,
    minMerge(READABILITY_PROMPT_MIN_STATE) as READABILITY_PROMPT_MIN,
    maxMerge(READABILITY_PROMPT_MAX_STATE) as READABILITY_PROMPT_MAX,
    avgMerge(READABILITY_RESPONSE_AVG_STATE) as READABILITY_RESPONSE_AVG,
    minMerge(READABILITY_RESPONSE_MIN_STATE) as READABILITY_RESPONSE_MIN,
    maxMerge(READABILITY_RESPONSE_MAX_STATE) as READABILITY_RESPONSE_MAX,
    
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
    
    -- Date dimensions for filtering
    EVENT_DATE,
    toStartOfHour(fromUnixTimestamp64Milli(FIRST_MESSAGE_TIMESTAMP)) as EVENT_HOUR,
    
    -- Add timestamp fields converted to DateTime for easier querying
    fromUnixTimestamp64Milli(FIRST_MESSAGE_TIMESTAMP) as FIRST_MESSAGE_TIME,
    fromUnixTimestamp64Milli(LAST_MESSAGE_TIMESTAMP) as LAST_MESSAGE_TIME
FROM traces_conversations_local
GROUP BY APP_ID, CONVERSATION_ID, FIRST_MESSAGE_TIMESTAMP, LAST_MESSAGE_TIMESTAMP, EVENT_DATE;

-- Create a Distributed view for conversations view
CREATE TABLE IF NOT EXISTS traces_conversations_view ON CLUSTER default
ENGINE = Distributed('default', neuraltrust, traces_conversations_view_local, rand());

-- Tests table
CREATE TABLE IF NOT EXISTS tests_local ON CLUSTER default (
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
) ENGINE = ReplicatedCollapsingMergeTree('/clickhouse/tables/{shard}/tests', '{replica}', sign)
ORDER BY (id, scenarioId, appId);

-- Create a Distributed table for tests
CREATE TABLE IF NOT EXISTS tests ON CLUSTER default AS tests_local
ENGINE = Distributed('default', neuraltrust, tests_local, rand());

-- Tests Runs table
CREATE TABLE IF NOT EXISTS test_runs_local ON CLUSTER default (
    id String,
    scenarioId String,
    appId String,
    testId String,
    type String,
    contextKeys Array(String),
    failure UInt8, -- Boolean in ClickHouse is represented as UInt8 (0 or 1)
    failCriteria String,
    testCase String, -- JSON stored as String
    score String,    -- JSON stored as String
    executionTimeSeconds Int32 NULL,
    runAt DateTime DEFAULT now(),
    sign Int8
) ENGINE = ReplicatedCollapsingMergeTree('/clickhouse/tables/{shard}/test_runs', '{replica}', sign)
ORDER BY (id, scenarioId, appId);

-- Create a Distributed table for test runs
CREATE TABLE IF NOT EXISTS test_runs ON CLUSTER default AS test_runs_local
ENGINE = Distributed('default', neuraltrust, test_runs_local, rand());