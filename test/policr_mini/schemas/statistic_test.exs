defmodule PolicrMini.Schemas.StatisticTest do
  use ExUnit.Case

  alias PolicrMini.Factory
  alias PolicrMini.Schemas.Statistic

  describe "schema" do
    test "schema metadata" do
      assert Statistic.__schema__(:source) == "statistics"

      assert Statistic.__schema__(:fields) ==
               [
                 :id,
                 :chat_id,
                 :beginning_date,
                 :ending_date,
                 :status_cont,
                 :verifications_count,
                 :top_1_language_code,
                 :top_2_language_code,
                 :inserted_at,
                 :updated_at
               ]
    end

    assert Statistic.__schema__(:primary_key) == [:id]
  end

  test "changeset/2" do
    statistic = Factory.build(:statistic, chat_id: 123_456_789_011)

    updated_status_cont = :wronged
    updated_verifications_count = 50
    updated_top_1_language_code = %{"zh-hans" => 99}

    params = %{
      "status_cont" => updated_status_cont,
      "verifications_count" => updated_verifications_count,
      "top_1_language_code" => updated_top_1_language_code
    }

    changes = %{
      status_cont: updated_status_cont,
      verifications_count: updated_verifications_count,
      top_1_language_code: updated_top_1_language_code
    }

    changeset = Statistic.changeset(statistic, params)
    assert changeset.params == params
    assert changeset.data == statistic
    assert changeset.changes == changes
    assert changeset.validations == []

    assert changeset.required == [
             :chat_id,
             :beginning_date,
             :ending_date,
             :status_cont
           ]

    assert changeset.valid?
  end
end
