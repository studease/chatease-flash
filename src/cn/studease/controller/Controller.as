package cn.studease.controller
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	
	import cn.studease.events.HTTPStatusEvent;
	import cn.studease.events.WebSocketEvent;
	import cn.studease.model.Model;
	import cn.studease.net.HttpResponse;
	import cn.studease.net.WebSocket;
	import cn.studease.utils.Logger;
	import cn.studease.view.View;

	public class Controller extends EventDispatcher
	{
		protected var _model:Model;
		protected var _view:View;
		
		private var _origin:String = 'http://127.0.0.1';
		private var _host:String = '127.0.0.1';
		private var _port:int = 80;
		private var _socket:Socket;
		private var _response:HttpResponse;
		private var _parser:WebSocket;
		private var _upgraded:Boolean;
		
		
		public function Controller(model:Model, view:View)
		{
			_model = model;
			_view = view;
			
			_origin = ExternalInterface.call(''
				+ 'function() {'
					+ 'return window.location.hostname;'
				+ '}');
			
			_response = new HttpResponse();
			_response.addEventListener(HTTPStatusEvent.HTTP_STATUS, _onHTTPStatus);
			_response.addEventListener(HTTPStatusEvent.ERROR, _onHTTPError);
			
			_parser = new WebSocket();
			_parser.addEventListener(WebSocketEvent.FRAME_DATA, _onWSFrameData);
			_parser.addEventListener(WebSocketEvent.ERROR, _onWSError);
			
			_initializeSocket();
		}
		
		protected function _initializeSocket():void {
			var re:RegExp = new RegExp('^ws[s]?\:\/\/([a-z0-9\.\-]+)(\:([0-9]*))?', 'i');
			var arr:Array = _model.config.url.match(re);
			if (arr && arr.length > 3) {
				_host = arr[1];
				_port = arr[3] || 80;
			} else {
				Logger.error('Failed to match websocket URL: ' + _model.config.url);
				_dispatchError('Bad URL format!');
				return;
			}
			
			_socket = new Socket();
			_socket.addEventListener(Event.CONNECT, _onConnect);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, _onSocketData);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _errorHandler);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, _errorHandler);
			_socket.addEventListener(Event.CLOSE, _onClose);
		}
		
		public function connect():void {
			if (!_socket.connected) {
				Logger.log('Connecting ' + _host + ':' + _port + ' ...');
				_socket.connect(_host, _port);
			}
		}
		
		public function send(text:String):void {
			if (!_socket.connected) {
				connect();
				return;
			}
			
			if (!_upgraded) {
				_dispatchError('Operation conflict!');
				return;
			}
			
			var ba:ByteArray = WebSocket.encode(text);
			
			Logger.debug(ba.toString());
			
			_socket.writeBytes(ba);
			_socket.flush();
		}
		
		protected function _onConnect(e:Event):void {
			Logger.log('Socket connected.');
			
			var handshake:String = ''
				+ 'GET ' + _model.config.url + ' HTTP/1.1\r\n'
				+ 'Host: ' + _host + '\r\n'
				+ 'User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:47.0) Gecko/20100101 Firefox/47.0\r\n'
				+ 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n'
				+ 'Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3\r\n'
				+ 'Sec-WebSocket-Version: 13\r\n'
				+ 'Origin: ' + _origin + '\r\n'
				+ 'Sec-WebSocket-Extensions: permessage-deflate\r\n'
				+ 'Sec-WebSocket-Key: Ya2QnRYTfukxZKysWaR8xQ==\r\n'
				+ 'Connection: keep-alive, Upgrade\r\n'
				+ 'Pragma: no-cache\r\n'
				+ 'Cache-Control: no-cache\r\n'
				+ 'Upgrade: websocket\r\n'
				+ '\r\n';
			
			_socket.writeUTFBytes(handshake);
			_socket.flush();
		}
		
		protected function _onSocketData(e:ProgressEvent):void {
			var buffer:ByteArray = new ByteArray();
			_socket.readBytes(buffer);
			
			Logger.debug(buffer.toString());
			
			if (_upgraded) {
				_parser.parse(buffer);
			} else {
				_response.parse(buffer);
				
				if (buffer.bytesAvailable) {
					var ba:ByteArray = new ByteArray();
					buffer.readBytes(ba);
					
					_parser.parse(ba);
				}
				
				//send('{"cmd":"text","data":"123","type":"multi","channel":{"id":"ch1"}}');
			}
		}
		
		protected function _errorHandler(e:ErrorEvent):void {
			Logger.log('onError: ' + e);
			
			_dispatchError(e.text);
		}
		
		protected function _onClose(e:Event):void {
			Logger.log('onClose');
			
			_upgraded = false;
			_dispatchClose();
		}
		
		protected function _onHTTPStatus(e:HTTPStatusEvent):void {
			Logger.log('HTTP status: ' + e.status + ' ' + e.explain);
			
			if (e.status !== HttpResponse.STU_HTTP_SWITCHING_PROTOCOLS) {
				_socket.close();
				_dispatchError('Unexpected http status: ' + e.status + ' ' + e.explain);
				return;
			}
			
			_upgraded = true;
			_dispatchOpen();
			
			//send('{"cmd":"text","data":"123","type":"multi","channel":{"id":"ch1"}}');
		}
		
		protected function _onHTTPError(e:WebSocketEvent):void {
			Logger.log('onHTTPError');
			
			_socket.close();
			_dispatchError(e.text);
		}
		
		protected function _onWSFrameData(e:WebSocketEvent):void {
			var ba:ByteArray = e.data as ByteArray;
			ba.position = 0;
			
			switch (e.opcode) {
				case WebSocket.STU_WEBSOCKET_OPCODE_TEXT:
				case WebSocket.STU_WEBSOCKET_OPCODE_BINARY:
					_dispatchMessage(ba.toString());
					break;
				
				case WebSocket.STU_WEBSOCKET_OPCODE_CLOSE:
					_socket.close();
					break;
				
				case WebSocket.STU_WEBSOCKET_OPCODE_PING:
					
					break;
				
				case WebSocket.STU_WEBSOCKET_OPCODE_PONG:
					
					break;
				
				default:
					_socket.close();
					_dispatchError('Unknown opcode: ' + e.opcode + '.');
					break;
			}
		}
		
		protected function _onWSError(e:WebSocketEvent):void {
			Logger.log('onWSError');
			
			_socket.close();
			_dispatchError(e.text);
		}
		
		public function close():void {
			if (_socket && _socket.connected) {
				_socket.close();
			}
		}
		
		
		protected function _dispatchOpen():void {
			ExternalInterface.call(''
				+ 'function() {'
					+ 'var chat = chatease("' + _model.config.id + '");'
					+ 'if (chat) {'
						+ 'chat.onSWFOpen();'
					+ '}'
				+ '}');
		}
		
		protected function _dispatchMessage(data:String):void {
			ExternalInterface.call(''
				+ 'function() {'
					+ 'var chat = chatease("' + _model.config.id + '");'
					+ 'if (chat) {'
						+ 'chat.onSWFMessage({ data: \'' + data + '\' });'
					+ '}'
				+ '}');
		}
		
		protected function _dispatchError(message:String):void {
			ExternalInterface.call(''
				+ 'function() {'
					+ 'var chat = chatease("' + _model.config.id + '");'
					+ 'if (chat) {'
						+ 'chat.onSWFError({ message: \'' + message + '\' });'
					+ '}'
				+ '}');
		}
		
		protected function _dispatchClose():void {
			ExternalInterface.call(''
				+ 'function() {'
					+ 'var chat = chatease("' + _model.config.id + '");'
					+ 'if (chat) {'
						+ 'chat.onSWFClose();'
					+ '}'
				+ '}');
		}
	}
}