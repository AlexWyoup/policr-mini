defmodule PolicrMini.VerificationBusiness do
  @moduledoc """
  验证的业务功能实现。
  """

  use PolicrMini, business: PolicrMini.Schemas.Verification

  alias PolicrMini.EctoEnums.{VerificationEntranceEnum, VerificationStatusEnum}

  import Ecto.Query, only: [from: 2, dynamic: 2]

  @typep written_returns :: {:ok, Verification.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  创建验证记录。
  """
  @spec create(%{optional(atom() | String.t()) => any()}) :: written_returns()
  def create(params) when is_map(params) do
    %Verification{} |> Verification.changeset(params) |> Repo.insert()
  end

  @doc """
  获取或创建验证记录。
  尝试获取已存在的验证记录时，仅获取统一入口下的等待验证记录。
  """
  @spec fetch(%{optional(atom() | String.t()) => any()}) :: written_returns()
  def fetch(%{chat_id: chat_id, target_user_id: target_user_id} = params) do
    case find_unity_waiting(chat_id, target_user_id) do
      nil -> create(params)
      r -> {:ok, r}
    end
  end

  @doc """
  更新验证记录。
  """
  @spec update(Verification.t(), %{optional(atom() | binary()) => any()}) :: written_returns()
  def update(%Verification{} = verification, params) do
    verification |> Verification.changeset(params) |> Repo.update()
  end

  @unity_entrance VerificationEntranceEnum.__enum_map__()[:unity]
  @waiting_status VerificationStatusEnum.__enum_map__()[:waiting]

  @doc """
  查找统一入口下最晚的等待验证。
  """
  @spec find_last_unity_waiting(integer()) :: Verification.t() | nil
  def find_last_unity_waiting(chat_id) when is_integer(chat_id) do
    from(p in Verification,
      where: p.chat_id == ^chat_id,
      where: p.entrance == ^@unity_entrance,
      where: p.status == ^@waiting_status,
      order_by: [desc: p.message_id],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  查找统一入口下最早的等待验证。
  """
  @spec find_first_unity_waiting(integer()) :: Verification.t() | nil
  def find_first_unity_waiting(chat_id) when is_integer(chat_id) do
    from(p in Verification,
      where: p.chat_id == ^chat_id,
      where: p.entrance == ^@unity_entrance,
      where: p.status == ^@waiting_status,
      order_by: [asc: p.message_id],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  获取统一入口的等待验证数量。
  """
  @spec get_unity_waiting_count(integer()) :: integer()
  def get_unity_waiting_count(chat_id) do
    from(p in Verification,
      select: count(p.id),
      where: p.chat_id == ^chat_id,
      where: p.entrance == ^@unity_entrance,
      where: p.status == ^@waiting_status
    )
    |> Repo.one()
  end

  @doc """
  查找统一入口的等待验证。
  """
  @spec find_unity_waiting(integer(), integer()) :: Verification.t() | nil
  def find_unity_waiting(chat_id, user_id) when is_integer(chat_id) and is_integer(user_id) do
    from(p in Verification,
      where: p.chat_id == ^chat_id,
      where: p.target_user_id == ^user_id,
      where: p.entrance == ^@unity_entrance,
      where: p.status == ^@waiting_status,
      order_by: [asc: p.inserted_at],
      limit: 1
    )
    |> Repo.one()
    |> Repo.preload([:chat])
  end

  @doc """
  获取最后一个统一入口的验证消息编号。
  """
  @spec find_last_unity_message_id(integer()) :: integer() | nil
  def find_last_unity_message_id(chat_id) do
    from(p in Verification,
      select: p.message_id,
      where: p.chat_id == ^chat_id,
      where: p.entrance == ^@unity_entrance,
      where: not is_nil(p.message_id),
      order_by: [desc: p.message_id],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  查找所有的还在等待的统一入口验证。
  """
  @spec find_all_unity_waiting() :: [Verification.t()]
  def find_all_unity_waiting() do
    from(p in Verification,
      where: p.entrance == ^@unity_entrance,
      where: p.status == ^@waiting_status,
      order_by: [asc: p.inserted_at]
    )
    |> Repo.all()
  end

  # TODO：使用 `find_total/1` 替代并删除。
  @doc """
  获取验证总数。
  """
  @spec get_total :: integer()
  def get_total do
    from(v in Verification, select: count(v.id)) |> Repo.one()
  end

  @type find_total_cont_status :: VerificationStatusEnum.t()
  @type find_total_cont :: [
          {:chat_id, integer},
          {:beginning_date_time, DateTime.t()},
          {:ending_date_time, DateTime.t()},
          {:status, find_total_cont_status}
        ]

  # TODO：添加测试。
  @doc """
  查找验证的总次数。
  """
  @spec find_total(find_total_cont) :: integer
  def find_total(cont \\ []) do
    filter_chat_id =
      if chat_id = Keyword.get(cont, :chat_id) do
        dynamic([v], v.chat_id == ^chat_id)
      else
        true
      end

    filter_beginning_date_time =
      if beginning_date_time = Keyword.get(cont, :beginning_date_time) do
        dynamic([v], v.inserted_at >= ^beginning_date_time)
      else
        true
      end

    filter_ending_date_time =
      if ending_date_time = Keyword.get(cont, :ending_date_time) do
        dynamic([v], v.inserted_at <= ^ending_date_time)
      else
        true
      end

    filter_status =
      if status = Keyword.get(cont, :status) do
        build_find_total_status_filter(status)
      else
        true
      end

    from(v in Verification,
      select: count(v.id),
      where: ^filter_chat_id,
      where: ^filter_beginning_date_time,
      where: ^filter_ending_date_time,
      where: ^filter_status
    )
    |> Repo.one()
  end

  defp build_find_total_status_filter(status) do
    dynamic([v], v.status == ^status)
  end

  @type find_list_cont :: [
          {:chat_id, integer | binary},
          {:limit, integer},
          {:offset, integer},
          {:status, :passed | :not_passed | :all},
          {:order_by, [{:desc | :asc, atom | [atom]}]}
        ]

  @default_find_list_limit 25
  @max_find_list_limit @default_find_list_limit

  @doc """
  查找验证记录列表。

  可选参数表示查询条件，部分条件存在默认和最大值限制。

  ## 查询条件
  - `chat_id`: 群组的 ID。
  - `limit`: 数量限制。默认值为 `25`，最大值为 `25`。如果条件中的值大于最大值将会被最大值重写。
  - `offset`: 偏移量。默认值为 `0`。
  - `order_by`: 排序方式，默认值为 `[desc: :inserted_at]`。
  """
  @spec find_list(find_list_cont) :: [Verification.t()]
  def find_list(cont \\ []) do
    filter_chat_id =
      if chat_id = Keyword.get(cont, :chat_id) do
        dynamic([v], v.chat_id == ^chat_id)
      else
        true
      end

    limit =
      if limit = Keyword.get(cont, :limit) do
        if limit > @max_find_list_limit, do: @max_find_list_limit, else: limit
      else
        @default_find_list_limit
      end

    offset = Keyword.get(cont, :offset, 0)
    order_by = Keyword.get(cont, :order_by, desc: :inserted_at)

    filter_status = build_find_list_status_filter(Keyword.get(cont, :status))

    from(v in Verification,
      where: ^filter_chat_id,
      where: ^filter_status,
      limit: ^limit,
      offset: ^offset,
      order_by: ^order_by
    )
    |> Repo.all()
  end

  defp build_find_list_status_filter(:passed) do
    dynamic([v], v.status == ^VerificationStatusEnum.__enum_map__()[:passed])
  end

  defp build_find_list_status_filter(:not_passed) do
    dynamic([v], v.status != ^VerificationStatusEnum.__enum_map__()[:passed])
  end

  defp build_find_list_status_filter(_), do: true

  @typedoc "语言代码数据的统计。它表达了语言代码和用户数量的映射关系。"
  @type language_code_stat :: %{language_code: String.t(), count: integer}
  @typedoc "查找语言代码的统计数据的条件。"
  @type find_language_code_stat :: [
          {:chat_id, integer},
          {:beginning_date_time, DateTime.t()},
          {:ending_date_time, DateTime.t()},
          {:status, VerificationStatusEnum.t()},
          {:limit, integer},
          {:order, :count_desc | :count_asc}
        ]

  @limit 2
  @default_find_language_code_stat_order [desc: :count]

  # TODO: 添加测试。
  @doc """
  查找语言代码的统计数据。

  通过可选条件查询语言代码的统计数据。

  ## 可选条件
  - `chat_id`: 群组 ID。
  - `beginning_date_time`: 开始日期时间。
  - `ending_date_time`: 结束日期时间。
  - `status`: 验证状态。
  - `limit`: 数量限制。默认值为 `2`。
  - `order`: 排序方式。有两种值，分别是 `:count_desc`（根据数量降序）和 `:count_asc`（根据数量升序）。默认值为 `:count_desc`。
  """
  @spec find_language_code_stat(find_language_code_stat) :: [language_code_stat]
  def find_language_code_stat(cont \\ []) do
    filter_chat_id =
      if chat_id = Keyword.get(cont, :chat_id) do
        dynamic([v], v.chat_id == ^chat_id)
      else
        true
      end

    filter_beginning_date_time =
      if beginning_date_time = Keyword.get(cont, :beginning_date_time) do
        dynamic([v], v.inserted_at >= ^beginning_date_time)
      else
        true
      end

    filter_ending_date_time =
      if ending_date_time = Keyword.get(cont, :ending_date_time) do
        dynamic([v], v.inserted_at <= ^ending_date_time)
      else
        true
      end

    filter_status =
      if status = Keyword.get(cont, :status) do
        dynamic([v], v.status == ^status)
      else
        true
      end

    limit = Keyword.get(cont, :limit, @limit)

    order_by =
      case Keyword.get(cont, :order, :count_desc) do
        :count_desc -> @default_find_language_code_stat_order
        :count_asc -> [asc: :count]
        _ -> @default_find_language_code_stat_order
      end

    from(
      v in Verification,
      select: %{
        language_code: v.target_user_language_code,
        count: count(v.target_user_id, :distinct)
      },
      where: ^filter_chat_id,
      where: ^filter_beginning_date_time,
      where: ^filter_ending_date_time,
      where: ^filter_status,
      where: not is_nil(v.target_user_language_code),
      group_by: v.target_user_language_code,
      order_by: ^order_by,
      limit: ^limit
    )
    |> Repo.all()
  end
end
