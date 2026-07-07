SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Index for User email
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.indexes 
        WHERE name = 'IX_Users_Email' 
        AND object_id = OBJECT_ID('dbo.Users')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users(Email);
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH
-- Index for User email
-- CREATE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users(Email);

-- Index Unique bắt buộc phải có để tầng ghi kiểm tra trùng lặp tài khoản khi đăng ký
CREATE UNIQUE NONCLUSTERED INDEX [IX_Users_Write_UserName] ON [Users_Write] ([UserName] ASC);
