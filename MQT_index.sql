CREATE NONCLUSTERED INDEX IX_MessageQueue_Status
ON dbo.Message_Queue (processed, priority DESC, created_at ASC);