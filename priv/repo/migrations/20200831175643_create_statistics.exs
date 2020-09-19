defmodule PolicrMini.Repo.Migrations.CreateStatistics do
  use PolicrMini.Migration

  alias PolicrMini.EctoEnums.VerificationStatusEnum

  def change do
    create table(:statistics) do
      add :chat_id, references(:chats), comment: "群组编号"
      add :beginning_date, :utc_datetime_usec, comment: "开始日期"
      add :ending_date, :utc_datetime_usec, comment: "结束日期"
      add :status_cont, VerificationStatusEnum.type(), comment: "验证状态（条件）"
      add :verifications_count, :integer, comment: "验证次数"
      add :top_1_language_code, {:map, :integer}, comment: "数量第一的语言代码"
      add :top_2_language_code, {:map, :integer}, comment: "数量第二的语言代码"

      timestamps()
    end
  end
end
