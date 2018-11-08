defmodule Comindivion.Api.PositionController do
  use Comindivion.Web, :controller

  alias Comindivion.MindObject
  alias Comindivion.Position

  import Ecto.Query, only: [from: 2]

  # NOTE: if node created on interactive view it already has position,
  #       otherwise there is no position for node and we must create it
  def bulk_update(conn, %{"mind_objects" => mind_objects}) do
    mind_object_ids = Map.keys(mind_objects)
    allowed_mind_object_ids =
      from(p in Position,
             join: mo in ^current_user_query(conn, MindObject), on: p.mind_object_id == mo.id,
             where: mo.id in ^mind_object_ids,
             select: mo.id)
      |> Repo.all

    positions_data =
      Enum.reduce(
        allowed_mind_object_ids,
        %{},
        fn(mo_id, acc) ->
          Map.put(acc, mo_id, mind_objects[mo_id])
        end
      )

    result =
      Comindivion.Context.Position.BulkUpdate.execute(
        positions_params: positions_data,
        user_id: current_user_id(conn)
      )

    case result do
      {:ok, multi_position_result, _}  ->
        result_data = %{positions: Map.values(multi_position_result)}

        Comindivion.Endpoint.broadcast(
          "interactive:#{current_user_id(conn)}",
          "interactive:network:node_positions:update",
          Comindivion.Serializer.Interactive.Position.json(result_data))

        render(conn, "show.json", result_data)
      {:error, :history} ->
        conn |> put_status(500) |> text("Internal server error: history problem")
      {:error, changeset} ->
        render(conn, "show.json", changeset: changeset)
    end
  end
end
