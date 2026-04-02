IF OBJECT_ID('dbo.CleanupMessageQueue_Dead', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CleanupMessageQueue_Dead;
GO

CREATE PROCEDURE dbo.CleanupMessageQueue_Dead
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BatchSize INT = 1000;

    WHILE 1 = 1
    BEGIN
        DELETE TOP (@BatchSize)
        FROM dbo.Message_Queue
        WHERE processed = 4
          AND created_at < DATEADD(DAY, -30, GETDATE()); -- ✅ keep 30 days

        IF @@ROWCOUNT = 0 BREAK;
    END
END
GO