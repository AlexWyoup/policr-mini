defmodule PolicrMini.StatisticBusiness do
  @moduledoc """
  数据统计的业务功能实现。
  """

  use PolicrMini, business: PolicrMini.Schemas.Statistic

  alias PolicrMini.EctoEnums.VerificationStatusEnum

  import Ecto.Query, only: [from: 2, dynamic: 2]

  @type written_returns :: {:ok, Statistic.t()} | {:error, Ecto.Changeset.t()}

  @spec create(map) :: written_returns
  def create(params) do
    %Statistic{} |> Statistic.changeset(params) |> Repo.insert()
  end

  @spec update(Statistic.t(), map) :: written_returns
  def update(stat, attrs) do
    stat |> Statistic.changeset(attrs) |> Repo.update()
  end

  @type find_latest_cont :: [{:chat_id, integer}, {:filter_status, VerificationStatusEnum.t()}]

  @spec find_latest(find_latest_cont) :: Statistic.t() | nil
  def find_latest(cont \\ []) do
    filter_chat_id =
      if chat_id = cont[:chat_id] do
        dynamic([s], s.chat_id == ^chat_id)
      else
        true
      end

    filter_status_cont =
      if status_cont = cont[:status_cont] do
        dynamic([s], s.status_cont == ^status_cont)
      else
        true
      end

    from(s in Statistic,
      where: ^filter_chat_id,
      where: ^filter_status_cont,
      limit: 1,
      order_by: [desc: :inserted_at]
    )
    |> Repo.one()
  end

  @spec gen_a_week(DateTime.t()) :: [Statistic.t()]
  def gen_a_week(_ending_date) do
    # TODO: 待实现。
    []
  end
end
