defmodule PolicrMini.StatisticBusiness do
  @moduledoc """
  数据统计的业务功能实现。
  """

  use PolicrMini, business: PolicrMini.Schemas.Statistic

  alias PolicrMini.EctoEnums.VerificationStatusEnum
  alias PolicrMini.VerificationBusiness

  import Ecto.Query, only: [from: 2, dynamic: 2]

  @type written_returns :: {:ok, Statistic.t()} | {:error, Ecto.Changeset.t()}

  @spec create(PolicrMini.Schema.params()) :: written_returns
  def create(params) do
    %Statistic{} |> Statistic.changeset(params) |> Repo.insert()
  end

  @spec update(Statistic.t(), map) :: written_returns
  def update(stat, attrs) do
    stat |> Statistic.changeset(attrs) |> Repo.update()
  end

  @spec fetch(PolicrMini.Schema.params()) :: written_returns | {:error, {:not_exists, atom}}
  def fetch(params) do
    existing_check = fn field ->
      if v = params[field] do
        {:ok, v}
      else
        {:not_exists, field}
      end
    end

    with {:ok, chat_id} <- existing_check.(:chat_id),
         {:ok, beginning_date} <- existing_check.(:beginning_date),
         {:ok, ending_date} <- existing_check.(:ending_date) do
      find_latest_cont = [
        chat_id: chat_id,
        beginning_date: beginning_date,
        ending_date: ending_date,
        status_cont: params[:status_cont]
      ]

      if stat = find_latest(find_latest_cont) do
        update(stat, params)
      else
        create(params)
      end
    else
      {:not_exists, field} -> {:error, {:not_exists, field}}
    end
  end

  @type find_latest_cont :: [
          {:chat_id, integer},
          {:status_cont, VerificationStatusEnum.t()},
          {:beginning_date, Date.t()},
          {:ending_date, Date.t()}
        ]

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

    filter_beginning_date =
      if beginning_date = cont[:beginning_date] do
        dynamic([s], s.beginning_date == ^beginning_date)
      end

    filter_ending_date =
      if ending_date = cont[:ending_date] do
        dynamic([s], s.ending_date == ^ending_date)
      end

    from(s in Statistic,
      where: ^filter_chat_id,
      where: ^filter_status_cont,
      where: ^filter_beginning_date,
      where: ^filter_ending_date,
      limit: 1,
      order_by: [desc: :inserted_at]
    )
    |> Repo.one()
  end

  @doc """
  生成一周的统计数据。

  ## 参数
  - `ending_date`: 结束日期。统计数据的范围将会从相对于此日期的七天前开始到此日期截至。
  - `chat_id`: 需要统计的群组 ID。
  """
  @spec gen_a_week(Date.t(), integer) ::
          {:ok, [Statistic.t()]} | {:error, Ecto.Changeset.t()} | {:error, {:not_exists, atom}}
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

    base_cont = [
      chat_id: chat_id,
      beginning_date_time: beginning_date_time,
      ending_date_time: ending_date_time
    ]

    passed_cont = base_cont ++ [status: :passed]
    timeout_cont = base_cont ++ [status: :timeout]
    wronged_cont = base_cont ++ [status: :wronged]

    count = VerificationBusiness.find_total(base_cont)
    passed_count = VerificationBusiness.find_total(passed_cont)
    timeout_count = VerificationBusiness.find_total(timeout_cont)
    wronged_count = VerificationBusiness.find_total(wronged_cont)

    language_code_stat = VerificationBusiness.find_language_code_stat(base_cont)
    passed_language_code_stat = VerificationBusiness.find_language_code_stat(passed_cont)
    timeout_language_code_stat = VerificationBusiness.find_language_code_stat(timeout_cont)
    wronged_language_code_stat = VerificationBusiness.find_language_code_stat(wronged_cont)

    get_top = fn language_code_stats, index ->
      if stat = Enum.at(language_code_stats, index) do
        %{stat[:language_code] => stat[:count]}
      else
        nil
      end
    end

    stat = %{
      chat_id: chat_id,
      beginning_date: beginning_date,
      ending_date: ending_date,
      verifications_count: count,
      status_cont: nil,
      top_1_language_code: get_top.(language_code_stat, 0),
      top_2_language_code: get_top.(language_code_stat, 1)
    }

    passed_stat = %{
      stat
      | verifications_count: passed_count,
        status_cont: :passed,
        top_1_language_code: get_top.(passed_language_code_stat, 0),
        top_2_language_code: get_top.(passed_language_code_stat, 1)
    }

    timeout_stat = %{
      stat
      | verifications_count: timeout_count,
        status_cont: :timeout,
        top_1_language_code: get_top.(timeout_language_code_stat, 0),
        top_2_language_code: get_top.(timeout_language_code_stat, 1)
    }

    wronged_stat = %{
      stat
      | verifications_count: wronged_count,
        status_cont: :wronged,
        top_1_language_code: get_top.(wronged_language_code_stat, 0),
        top_2_language_code: get_top.(wronged_language_code_stat, 1)
    }

    Repo.transaction(fn ->
      with {:ok, stat} <- fetch(stat),
           {:ok, passed_stat} <- fetch(passed_stat),
           {:ok, timeout_stat} <- fetch(timeout_stat),
           {:ok, wronged_stat} <- fetch(wronged_stat) do
        [stat, passed_stat, timeout_stat, wronged_stat]
      else
        {:error, reason} = _e ->
          Repo.rollback(reason)
      end
    end)
  end
end
