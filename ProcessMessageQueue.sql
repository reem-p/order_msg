IF OBJECT_ID('dbo.ProcessMessageQueue', 'P') IS NOT NULL
    DROP PROCEDURE dbo.ProcessMessageQueue;
GO

CREATE PROCEDURE dbo.ProcessMessageQueue
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batchSize INT = 20;
    DECLARE @MaxRetry INT = 3;

    WHILE EXISTS (
        SELECT 1
        FROM dbo.Message_Queue
        WHERE processed IN (0,3)
          AND ISNULL(retry_count,0) < @MaxRetry
    )
    BEGIN
        IF OBJECT_ID('tempdb..#TempProcessing') IS NOT NULL
            DROP TABLE #TempProcessing;

        CREATE TABLE #TempProcessing (
            Id INT,
            msg_type INT,
            mobileNO NVARCHAR(50),
            msg_amt DECIMAL(18,2),
            order_no NVARCHAR(50),
            order_name NVARCHAR(100)
        );

        ;WITH ToProcess AS (
            SELECT TOP (@batchSize) *
            FROM dbo.Message_Queue WITH (READPAST, UPDLOCK, ROWLOCK)
            WHERE processed IN (0,3)
              AND ISNULL(retry_count,0) < @MaxRetry
            ORDER BY priority DESC, created_at ASC
        )
        UPDATE ToProcess
        SET processed = 2
        OUTPUT 
            inserted.Id,
            inserted.msg_type,
            inserted.MQ_oh_telephone,
            CASE 
                WHEN inserted.msg_type IN (1,2) 
                    THEN inserted.MQ_oh_total_amt
                WHEN inserted.msg_type = 4 
                    THEN ISNULL(inserted.MQ_InstallmentValue,0) 
                       + ISNULL(inserted.MQ_penalty_value,0)
                ELSE 0
            END,
            inserted.MQ_order_no,
            inserted.MQ_order_name
        INTO #TempProcessing;

        DECLARE 
            @Id INT,
            @msg_type INT,
            @mobileNO NVARCHAR(50),
            @msg_amt DECIMAL(18,2),
            @order_no NVARCHAR(50),
            @order_name NVARCHAR(100);

        DECLARE cur CURSOR FOR
        SELECT Id, msg_type, mobileNO, msg_amt, order_no, order_name
        FROM #TempProcessing;

        OPEN cur;
        FETCH NEXT FROM cur INTO @Id, @msg_type, @mobileNO, @msg_amt, @order_no, @order_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                IF @mobileNO IS NULL OR LTRIM(RTRIM(@mobileNO)) = ''
                BEGIN
                    UPDATE dbo.Message_Queue
                    SET processed = 1
                    WHERE Id = @Id;

                    FETCH NEXT FROM cur INTO @Id, @msg_type, @mobileNO, @msg_amt, @order_no, @order_name;
                    CONTINUE;
                END

                EXEC dbo.MessageCenter_Proc
                    @msg_type = @msg_type,
                    @mobileNO = @mobileNO,
                    @msg_amt = @msg_amt,
                    @order_no = @order_no,
                    @order_name = @order_name;

                UPDATE dbo.Message_Queue
                SET processed = 1
                WHERE Id = @Id;
            END TRY
            BEGIN CATCH
                DECLARE @NewRetry INT;

                SELECT @NewRetry = ISNULL(retry_count,0) + 1
                FROM dbo.Message_Queue
                WHERE Id = @Id;

                UPDATE dbo.Message_Queue
                SET 
                    retry_count = @NewRetry,
                    last_attempt = GETDATE(),
                    processed = CASE 
                                  WHEN @NewRetry >= @MaxRetry THEN 4
                                  ELSE 3
                                END,
                    error_message = ERROR_MESSAGE()
                WHERE Id = @Id;
            END CATCH

            FETCH NEXT FROM cur INTO @Id, @msg_type, @mobileNO, @msg_amt, @order_no, @order_name;
        END

        CLOSE cur;
        DEALLOCATE cur;
    END
END
GO