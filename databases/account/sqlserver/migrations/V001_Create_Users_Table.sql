
CREATE TABLE [users] (
[UserName] [NVARCHAR](150) NOT NULL,
[EmailAddress] [NVARCHAR](250) NULL,
[Password] [NVARCHAR](MAX) NULL,
[PhoneNumber] [VARCHAR](50) NULL,
[PasswordSalt] [NVARCHAR](MAX) NULL,
[Status] [INT] NOT NULL,
[Code] [VARCHAR](32) NOT NULL,
[NumericalOrder] [BIGINT] IDENTITY(1, 1) NOT NULL,
[CreatedDate] [DATETIME2](7) NOT NULL,
[CreatedDateUtc] [DATETIME2](7) NOT NULL,
[CreatedUid] [NVARCHAR](250) NULL,
[UpdatedDate] [DATETIME2](7) NOT NULL,
[UpdatedDateUtc] [DATETIME2](7) NOT NULL,
[UpdatedUid] [NVARCHAR](250) NULL,
[LoginUid] [NVARCHAR](250) NULL,
[Version] [INT] NOT NULL,
CONSTRAINT [PK_Users_Write] PRIMARY KEY CLUSTERED ([Code] ASC)
);

