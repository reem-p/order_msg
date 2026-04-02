IF OBJECT_ID('dbo.CleanupMessageQueue_Daily', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CleanupMessageQueue_Daily;
GO

CREATE PROCEDURE dbo.CleanupMessageQueue_Daily
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BatchSize INT = 1000;

    WHILE 1 = 1
    BEGIN
        DELETE TOP (@BatchSize)
        FROM dbo.Message_Queue
        WHERE processed = 1
         -- AND created_at < DATEADD(DAY, -1, GETDATE()); -- ✅ keep recent 1 day

        IF @@ROWCOUNT = 0 BREAK;
    END
END
GO