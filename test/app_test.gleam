import app
import ewe
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/otp/actor
import gleam/string
import gleeunit
import stratus

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn ewe_01_test() {
  let assert Ok(_started) = app.start(8080)
  let assert Ok(req) = request.to("http://localhost:8080/hello/wibble")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 200
  assert response.get_header(resp, "content-type")
    == Ok("text/plain; charset=utf-8")
  assert resp.body == "Hello, wibble!"
}

pub fn ewe_02_test() {
  let assert Ok(_started) = app.start(8081)
  let assert Ok(req) = request.to("http://localhost:8081/echo")
  let body = string.repeat("a", 1040)

  let assert Ok(resp) =
    request.set_body(req, body)
    |> request.set_header("content-type", "text/plain; charset=utf-8")
    |> request.set_header("content-length", "1040")
    |> httpc.send

  assert resp.status == 413
  assert resp.body == "Body too large"
}

pub fn ewe_03_test() {
  let assert Ok(_started) = app.start(8082)
  let assert Ok(req) = request.to("http://localhost:8082/file/index.html")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 404
  assert response.get_header(resp, "content-type")
    == Ok("text/plain; charset=utf-8")
  assert resp.body == "File not found"
}

pub fn ewe_04_test() {
  let assert Ok(_started) = app.start(8083)
  let assert Ok(req) = request.to("http://localhost:8083/bytes/32")

  let assert Ok(resp) = request.set_body(req, <<>>) |> httpc.send_bits
  assert resp.status == 200
  assert response.get_header(resp, "content-type")
    == Ok("application/octet-stream")
  assert response.get_header(resp, "content-length") == Ok("32")
  assert bit_array.byte_size(resp.body) == 32
}

pub fn ewe_05_test() {
  let assert Ok(_started) = app.start(8084)
  let assert Ok(req) = request.to("http://localhost:8084/topic/test_room/ws")

  let assert Ok(actor.Started(pid:, data: client)) =
    stratus.new(req, Nil)
    |> stratus.on_message(fn(state, message, conn) {
      case message {
        stratus.User(text) -> {
          assert stratus.send_text_message(conn, text) == Ok(Nil)
          stratus.continue(state)
        }
        _ -> {
          assert message == stratus.Text("Wibble Wobble")
          stratus.stop()
        }
      }
    })
    |> stratus.start

  stratus.to_user_message("Wibble Wobble")
  |> process.send(client, _)

  let assert Ok(process.ProcessDown(_monitor, _pid, process.Normal)) =
    process.new_selector()
    |> process.select_specific_monitor(process.monitor(pid), function.identity)
    |> process.selector_receive(1000)
}

pub fn ewe_06_test() {
  let assert Ok(_started) = app.start(3000)
  let assert Ok(req) = request.to("http://localhost:3000/hello/wibble")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 200
  assert response.get_header(resp, "content-type")
    == Ok("text/plain; charset=utf-8")
  assert resp.body == "Hello, wibble!"

  let assert Ok(req) = request.to("http://localhost:8085/hello/wibble")
  let assert Error(_) = httpc.send(req)
}

pub fn ewe_07_test() {
  let assert Ok(_started) = app.start(8085)
  let assert Ok(req) = request.to("http://localhost:8085/search?q=wibble")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 200
  assert response.get_header(resp, "content-type")
    == Ok("text/plain; charset=utf-8")
  assert resp.body == "wibble"
}

pub fn ewe_08_test() {
  let assert Ok(_started) = app.start(8086)
  let assert Ok(req) = request.to("http://localhost:8086/partional")

  let assert Ok(resp) = httpc.send(req)
  assert resp.status == 200
  assert resp.body == "345"
}

pub fn ewe_09_test() {
  process.trap_exits(True)

  let assert Error(actor.InitFailed(..)) =
    ewe.new(fn(_req) {
      response.new(200)
      |> response.set_body(ewe.Empty)
    })
    |> ewe.enable_tls("", "")
    |> ewe.start
}

pub fn ewe_10_test() {
  let assert Ok(_started) = app.start(8087)
  let assert Ok(req) = request.to("http://localhost:8087/echo")

  let assert Ok(resp) =
    request.set_body(req, "Wibble Wobble")
    |> request.set_header("content-type", "text/plain; charset=utf-8")
    |> request.set_header("content-length", "13")
    |> httpc.send

  assert resp.status == 400
}
