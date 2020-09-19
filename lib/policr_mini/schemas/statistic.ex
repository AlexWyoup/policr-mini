defmodule PolicrMini.Schemas.Statistic do
  @moduledoc """
  统计模型。
  """

  use PolicrMini.Schema

  @required_fields ~w(chat_id beginning_date ending_date)a
  @optional_fields ~w(
                      status_cont
                      verifications_count
                      top_1_language_code
                      top_2_language_code
                    )a

  alias PolicrMini.Schemas.Chat
  alias PolicrMini.EctoEnums.VerificationStatusEnum

  @primary_key {:id, :integer, autogenerate: false}
  schema "statistics" do
    belongs_to :chat, Chat
    field :beginning_date, :date
    field :ending_date, :date
    field :status_cont, VerificationStatusEnum
    field :verifications_count, :integer
    field :top_1_language_code, {:map, :integer}
    field :top_2_language_code, {:map, :integer}

    timestamps()
  end

  @type t :: Ecto.Schema.t()

  def changeset(%__MODULE__{} = chat, attrs) when is_map(attrs) do
    chat
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:chat)
  end
end
