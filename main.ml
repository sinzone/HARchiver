open Core.Std
open Lwt
open Cohttp_lwt
open Cohttp_lwt_unix
open Cohttp_lwt_unix_io
open Har_j

module Body = Cohttp_lwt_body
module CLU = Conduit_lwt_unix
exception Too_many_requests

let get_ZMQ_sock remote =
	let ctx = ZMQ.Context.create () in
	let raw_sock = ZMQ.Socket.create ctx ZMQ.Socket.push in
	ZMQ.Socket.connect raw_sock remote;
	print_endline ("Attempting to connect to "^remote);
	Lwt_zmq.Socket.of_socket raw_sock

let get_timestamp () = Time.now () |> Time.to_float |> Int.of_float

let stream_length stream = Lwt_stream.fold (fun a b -> (String.length a)+b) stream 0

let get_addr_from_ch = function
| CLU.TCP {CLU.fd; ip; port} -> begin
	match Lwt_unix.getpeername fd with
	| Lwt_unix.ADDR_INET (ia,port) -> Ipaddr.to_string (Ipaddr_unix.of_inet_addr ia)
	| Lwt_unix.ADDR_UNIX path -> sprintf "sock:%s" path end
| _ -> ""

let rec fork = function
| 0 -> 0
| n -> match Lwt_unix.fork () with
	| 0 -> fork (n - 1)
	| pid -> pid

let make_server port concurrency key =
	let nb_current = ref 0 in
	let sock = get_ZMQ_sock "tcp://server.apianalytics.com:5000" in
	let global_archive = Option.map key (fun k -> (module Archive.Make (struct let key = k end) : Archive.Sig_make)) in
	let send_har archive req res t_client_length t_provider_length timings =
		t_client_length
		>>= fun client_length -> t_provider_length
		>>= fun provider_length ->
			let module KeyArchive = (val archive : Archive.Sig_make) in

			Lwt_zmq.Socket.send sock (KeyArchive.get_har req res client_length provider_length timings |> string_of_har ~len:1024)
	in
	let callback (ch,_) req client_body =
		let () = nb_current := (!nb_current + 1) in

		let har_init = get_timestamp () in
		let client_uri = Request.uri req in
		let client_headers = Request.headers req in
		let t_client_length = Body.to_stream client_body |> Lwt_stream.clone |> stream_length in
		let har_send = (get_timestamp ()) - har_init in
		let local_archive = Option.map (Cohttp.Header.get client_headers "Service-Token") ~f:(fun k ->
			(module Archive.Make (struct let key = k end) : Archive.Sig_make)) in

		let response = try_lwt (
			if !nb_current > concurrency then raise Too_many_requests else
			match Option.first_some local_archive global_archive with
			| None -> raise (Failure "Service-Token missing")
			| Some archive ->
				let client_headers_ready = Cohttp.Header.remove client_headers "Service-Token"
					|> fun h -> Cohttp.Header.remove h "Host" (* Automatically added by Cohttp *)
					|> fun h -> Cohttp.Header.add h "X-Forwarded-For" "0.0.0.0" in
					(* |> fun h -> Cohttp.Header.add h "X-Forwarded-For" (get_addr_from_ch ch) in *)
				let remote_call = Client.call ~headers:client_headers_ready ~body:client_body (Request.meth req) client_uri
				>>= fun (res, provider_body) ->
					let har_wait = (get_timestamp ()) - har_init in
					let provider_headers = Cohttp.Header.remove (Response.headers res) "content-length" in (* Because we're using Transfer-Encoding: Chunked *)
					let t_provider_length = Body.to_stream provider_body |> Lwt_stream.clone |> stream_length in
					let har_receive = (get_timestamp ()) - har_init in
					let _ = send_har archive req res t_client_length t_provider_length (har_send, har_wait, har_receive) in
					Server.respond ~headers:provider_headers ~status:(Response.status res) ~body:provider_body ()
				in
				Lwt.pick [remote_call; Lwt_unix.timeout 8.]
		) with ex ->
			let (error_code, error_text) = match ex with
			| Lwt_unix.Timeout ->
				(504, "504: The server timed out trying to establish a connection")
			| Too_many_requests ->
				(503, "503: The server is under heavy load, try again")
			| _ ->
				(500, ("500: "^(Exn.to_string ex)))
			in
			let _ = Lwt_io.printl error_text in
			let har_wait = (get_timestamp ()) - har_init in
			let t_res = Server.respond_error ~status:(Cohttp.Code.status_of_code error_code) ~body:error_text () in
			let _ = t_res >>= fun (res, body) ->
				let t_provider_length = Body.to_stream body |> Lwt_stream.clone |> stream_length in
				match Option.first_some local_archive global_archive with
				| None -> return ()
				| Some archive -> send_har archive req res t_client_length t_provider_length (har_wait, har_send, 0)
			in t_res
		in
		let _ = response >>= fun _ -> return (nb_current := (!nb_current - 1)) in
		response
	in
	let conn_closed (_,_) () = () in
	let config = {Server.callback; conn_closed} in
	let ctx = Cohttp_lwt_unix_net.init () in
	let tcp_mode = `TCP (`Port port) in
	let ssl_mode = `OpenSSL (`Crt_file_path "cert.pem", `Key_file_path "key.pem", `No_password, `Port (port+1)) in
	let tcp_server = Server.create ~ctx ~mode:tcp_mode config in
	let ssl_server = Server.create ~ctx ~mode:ssl_mode config in
	let _ = Lwt_io.printf "HTTP  server listening on port %n\nHTTPS server listening on port %n\n" port (port+1) in

	match fork 3 with
	| 0 -> Lwt_unix.sleep 40. >>= fun () -> exit 0
	| _ -> tcp_server <&> ssl_server

let start port concurrency key () = Lwt_unix.run (make_server port concurrency key)

let command =
	Command.basic
		~summary:"Transparent analytics layer for apianalytics.com"
		~readme:(fun () -> "Portable, fast and transparent proxy.\n
			It lets HTTP traffic through and streams datapoints to apianalytics.com\n
			If a Service-Token isn't specified at startup, it needs to be in a header for every request.")
		Command.Spec.(
			empty
			+> anon ("port" %: int)
			+> anon ("concurrency" %: int)
			+> anon (maybe ("service_token" %: string))
		)
		start

(* let () = start 15000 (Some "DEFAULT") () *)

let () = Command.run ~version:"0.9" ~build_info:"github.com/SGrondin/analytics-harchiver" command
