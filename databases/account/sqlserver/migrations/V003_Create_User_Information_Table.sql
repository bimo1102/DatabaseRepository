
CREATE TABLE [UserInformation_Write] (
[FullName] [NVARCHAR](250) NULL,
[DateOfBirth] [DATE] NULL,
[Gender] [INT] NULL,
[IdentificationNumber] [VARCHAR](50) NULL,
[CompanyName] [NVARCHAR](250) NULL,
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
    CONSTRAINT [PK_UserInformation_Write] PRIMARY KEY CLUSTERED ([Code] ASC)
);