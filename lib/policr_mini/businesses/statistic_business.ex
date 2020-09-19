defmodule PolicrMini.StatisticBusiness do
  @moduledoc """
  数据统计的业务功能实现。
  """

  use PolicrMini, business: PolicrMini.Schemas.Statistic

  alias PolicrMini.Logger
  alias PolicrMini.EctoEnums.VerificationStatusEnum
  alias PolicrMini.VerificationBusiness

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

  @spec gen_a_week(Date.t(), integer) :: {:ok, [Statistic.t()]} | {:error, any}
  def gen_a_week(ending_date, chat_id) do
    to_naive_dt = fn date ->
      erl = Date.to_erl(date)

      NaiveDateTime.from_erl!({erl, {0, 0, 0}})
    end

    beginning_date = Date.add(ending_date, -7)

    beginning_date_time =
      beginning_date
      |> to_naive_dt.()
      |> DateTime.from_naive!("Etc/UTC")

    ending_date_time =
      ending_date
      |> to_naive_dt.()
      |> DateTime.from_naive!("Etc/UTC")

    # TODO: 缺乏对已存在的统计数据的检查。

    count_cont = [
      chat_id: chat_id,
      beginning_date_time: beginning_date_time,
      ending_date_time: ending_date_time
    ]

    passed_count_cont = count_cont ++ [status: :passed]
    timeout_count_cont = count_cont ++ [status: :timeout]
    wronged_count_cont = count_cont ++ [status: :wronged]

    count = VerificationBusiness.find_total(count_cont)
    passed_count = VerificationBusiness.find_total(passed_count_cont)
    timeout_count = VerificationBusiness.find_total(timeout_count_cont)
    wronged_count = VerificationBusiness.find_total(wronged_count_cont)

    # TODO: 缺乏语言代码统计。

    stat = %{
      chat_id: chat_id,
      beginning_date: beginning_date,
      ending_date: ending_date,
      verifications_count: count,
      status_cont: nil
    }

    passed_stat = %{stat | verifications_count: passed_count, status_cont: :passed}
    timeout_stat = %{stat | verifications_count: timeout_count, status_cont: :timeout}
    wronged_stat = %{stat | verifications_count: wronged_count, status_cont: :wronged}

    Repo.transaction(fn ->
      with {:ok, stat} <- create(stat),
           {:ok, passed_stat} <- create(passed_stat),
           {:ok, timeout_stat} <- create(timeout_stat),
           {:ok, wronged_stat} <- create(wronged_stat) do
        [stat, passed_stat, timeout_stat, wronged_stat]
      else
        e ->
          Logger.unitized_error("Statistics generation", e)

          e
      end
    end)
  end
end
