CREATE TABLE dbo.Message_Queue (
    Id INT IDENTITY PRIMARY KEY,

    msg_type INT,

    -- original data (prefixed MQ)
    MQ_oh_telephone NVARCHAR(50),
    MQ_oh_total_amt DECIMAL(18,2),
    MQ_installment_value DECIMAL(18,2),
    MQ_penalty_value DECIMAL(18,2),
    MQ_order_no NVARCHAR(50),
    MQ_order_name NVARCHAR(100),

    -- system columns
    created_at DATETIME DEFAULT GETDATE(),
    priority INT DEFAULT 0,

    processed INT DEFAULT 0, 

    retry_count INT DEFAULT 0,
    last_attempt DATETIME,

    error_message NVARCHAR(MAX)
);