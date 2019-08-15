defmodule Dawdle.Backend.SQSTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias Dawdle.Backend.SQS
  alias ExAws.Operation.Query
  alias Faker.Lorem

  setup_all do
    Dawdle.stop_pollers()
  end

  setup do
    # This is cheating a little bit to get the queue names
    message_queue = hd(SQS.queues())
    delay_queue = hd(Enum.reverse(SQS.queues()))

    {:ok, message_queue: message_queue, delay_queue: delay_queue}
  end

  describe "send/1" do
    test "sending a single message", %{message_queue: q} do
      path = "/#{q}"
      message = Lorem.sentence()

      with_mock ExAws,
        request: fn %Query{
                      action: :send_message,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "SendMessage",
                        "MessageBody" => ^message
                      }
                    },
                    _ ->
          {:ok, "testing"}
        end do
        assert :ok = SQS.send([message])
      end
    end

    test "sending a single message when there is an error" do
      with_mock ExAws, request: fn _, _ -> {:error, :testing} end do
        assert capture_log(fn ->
                 assert {:error, :testing} = SQS.send([Lorem.sentence()])
               end) =~ "{:error, :testing}"
      end
    end

    test "sending multiple messages", %{message_queue: q} do
      path = "/#{q}"
      message1 = Lorem.sentence()
      message2 = Lorem.sentence()

      with_mock ExAws,
        request: fn %Query{
                      action: :send_message_batch,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "SendMessageBatch",
                        "SendMessageBatchRequestEntry.1.MessageBody" =>
                          ^message1,
                        "SendMessageBatchRequestEntry.2.MessageBody" =>
                          ^message2
                      }
                    },
                    _ ->
          {:ok, "testing"}
        end do
        assert :ok = SQS.send([message1, message2])
      end
    end

    test "sending multiple messages when there is an error" do
      with_mock ExAws, request: fn _, _ -> {:error, :testing} end do
        assert capture_log(fn ->
                 assert {:error, :testing} =
                          SQS.send([Lorem.sentence(), Lorem.sentence()])
               end) =~ "{:error, :testing}"
      end
    end
  end

  describe "send_after/1" do
    test "sending a delayed message", %{delay_queue: q} do
      path = "/#{q}"
      message = Lorem.sentence()

      with_mock ExAws,
        request: fn %Query{
                      action: :send_message,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "SendMessage",
                        "DelaySeconds" => 10,
                        "MessageBody" => ^message
                      }
                    },
                    _ ->
          {:ok, "testing"}
        end do
        assert :ok = SQS.send_after(message, 10)
      end
    end

    test "sending a delayed message when there is an error" do
      with_mock ExAws, request: fn _, _ -> {:error, :testing} end do
        assert capture_log(fn ->
                 assert {:error, :testing} =
                          SQS.send_after(Lorem.sentence(), 10)
               end) =~ "{:error, :testing}"
      end
    end
  end

  describe "recv/1" do
    test "receiving messages", %{message_queue: q} do
      path = "/#{q}"
      messages = [Lorem.sentence()]

      with_mock ExAws,
        request: fn %Query{
                      action: :receive_message,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "ReceiveMessage",
                        "MaxNumberOfMessages" => 10
                      }
                    },
                    _ ->
          {:ok, %{body: %{messages: messages}}}
        end do
        assert {:ok, messages} = SQS.recv(q)
      end
    end

    test "empty receives", %{message_queue: q} do
      path = "/#{q}"
      messages = [Lorem.sentence()]
      {:ok, agent} = Agent.start_link(fn -> true end)

      with_mock ExAws,
        request: fn %Query{
                      action: :receive_message,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "ReceiveMessage",
                        "MaxNumberOfMessages" => 10
                      }
                    },
                    _ ->
          if Agent.get(agent, & &1) do
            Agent.update(agent, fn _ -> false end)
            {:ok, %{body: %{messages: []}}}
          else
            {:ok, %{body: %{messages: messages}}}
          end
        end do
        assert {:ok, messages} = SQS.recv(q)
      end
    end

    test "receiving messages when there is an error", %{message_queue: q} do
      with_mock ExAws, request: fn _, _ -> {:error, :testing} end do
        assert capture_log(fn ->
                 assert {:error, :testing} = SQS.recv(q)
               end) =~ "{:error, :testing}"
      end
    end
  end

  describe "delete/2" do
    test "deleting messages", %{message_queue: q} do
      path = "/#{q}"
      messages = [%{receipt_handle: 1}]

      with_mock ExAws,
        request: fn %Query{
                      action: :delete_message_batch,
                      service: :sqs,
                      path: ^path,
                      params: %{
                        "Action" => "DeleteMessageBatch",
                        "DeleteMessageBatchRequestEntry.1.Id" => "0",
                        "DeleteMessageBatchRequestEntry.1.ReceiptHandle" => 1
                      }
                    },
                    _ ->
          {:ok, :testing}
        end do
        assert :ok = SQS.delete(q, messages)
      end
    end

    test "deleting messages when there is an error", %{message_queue: q} do
      messages = [%{receipt_handle: 1}]

      with_mock ExAws, request: fn _, _ -> {:error, :testing} end do
        assert capture_log(fn ->
                 assert {:error, :testing} = SQS.delete(q, messages)
               end) =~ "{:error, :testing}"
      end
    end
  end
end