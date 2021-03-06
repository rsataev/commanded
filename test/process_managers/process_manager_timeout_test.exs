defmodule Commanded.ProcessManagers.ProcessManagerTimeoutTest do
  use Commanded.StorageCase

  alias Commanded.Helpers.Wait
  alias Commanded.ProcessManagers.ProcessRouter
  alias Commanded.ProcessManagers.{ExampleRouter, ExampleProcessManager}
  alias Commanded.ProcessManagers.ExampleAggregate.Commands.{Pause, Start}

  test "should not timeout and shutdown process manager by default" do
    aggregate_uuid = UUID.uuid4()

    {:ok, process_router} = ExampleProcessManager.start_link()
    router_ref = Process.monitor(process_router)

    :ok = ExampleRouter.dispatch(%Start{aggregate_uuid: aggregate_uuid})

    process_instance = wait_for_process_instance(process_router, aggregate_uuid)
    instance_ref = Process.monitor(process_instance)

    :ok = ExampleRouter.dispatch(%Pause{aggregate_uuid: aggregate_uuid})

    # Should not shutdown process manager or instance
    refute_receive {:DOWN, ^router_ref, _, _, _}
    refute_receive {:DOWN, ^instance_ref, _, _, _}
  end

  test "should timeout and shutdown process manager when `event_timeout` configured" do
    aggregate_uuid = UUID.uuid4()

    {:ok, process_router} = ExampleProcessManager.start_link(event_timeout: 100)

    router_ref = Process.monitor(process_router)
    Process.unlink(process_router)

    :ok = ExampleRouter.dispatch(%Start{aggregate_uuid: aggregate_uuid})

    process_instance = wait_for_process_instance(process_router, aggregate_uuid)
    instance_ref = Process.monitor(process_instance)

    :ok = ExampleRouter.dispatch(%Pause{aggregate_uuid: aggregate_uuid})

    # Should shutdown process manager and instance
    assert_receive {:DOWN, ^router_ref, _, _, :event_timeout}
    assert_receive {:DOWN, ^instance_ref, _, _, :shutdown}
  end

  defp wait_for_process_instance(process_router, aggregate_uuid) do
    Wait.until(fn ->
      process_instance = ProcessRouter.process_instance(process_router, aggregate_uuid)

      assert is_pid(process_instance)

      process_instance
    end)
  end
end
