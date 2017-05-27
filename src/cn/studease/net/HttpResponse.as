package cn.studease.net
{
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	
	import cn.studease.events.HTTPStatusEvent;

	public class HttpResponse extends EventDispatcher
	{
		public static const STU_HTTP_VERSION_10:int =            10;
		public static const STU_HTTP_VERSION_11:int =            11;
		
		public static const STU_HTTP_SWITCHING_PROTOCOLS:int =   101;
		public static const STU_HTTP_OK:int =                    200;
		public static const STU_HTTP_NOTIFICATION:int =          209;
		public static const STU_HTTP_MOVED_TEMPORARILY:int =     302;
		
		public static const STU_HTTP_BAD_REQUEST:int =           400;
		public static const STU_HTTP_UNAUTHORIZED:int =          401;
		public static const STU_HTTP_FORBIDDEN:int =             403;
		public static const STU_HTTP_NOT_FOUND:int =             404;
		public static const STU_HTTP_METHOD_NOT_ALLOWED:int =    405;
		public static const STU_HTTP_REQUEST_TIMEOUT:int =       408;
		public static const STU_HTTP_CONFLICT:int =              409;
		
		public static const STU_HTTP_INTERNAL_SERVER_ERROR:int = 500;
		public static const STU_HTTP_NOT_IMPLEMENTED:int =       501;
		public static const STU_HTTP_BAD_GATEWAY:int =           502;
		public static const STU_HTTP_SERVICE_UNAVAILABLE:int =   503;
		public static const STU_HTTP_GATEWAY_TIMEOUT:int =       504;
		
		public static const CR:String = '\r';
		public static const LF:String = '\n';
		
		protected var _version:uint;
		protected var _status:uint;
		protected var _explain:String;
		
		protected var _buffer:ByteArray;
		protected var _headers:Object;
		protected var _content:ByteArray;
		
		protected var _state:uint;
		protected var _pos:uint;
		protected var _done:Boolean;
		
		
		public function HttpResponse()
		{
			_buffer = new ByteArray();
			_headers = {};
			
			_state = 0;
			_pos = 0;
			_done = false;
		}
		
		public function parse(buffer:ByteArray):void {
			if (buffer.bytesAvailable == 0) {
				return;
			}
			
			buffer.readBytes(_buffer, _buffer.length);
			
			if (_pos == 0) {
				_buffer.position = 0;
				_parseStatusLine(_buffer);
			}
			
			if (_done == false) {
				_parseHeaders(_buffer);
			}
			
			if (_done == false) { // headers not complete
				return;
			}
			
			if (_headers.hasOwnProperty('content-length')) {
				var len:int = parseInt(_headers['content-length']);
				if (_buffer.bytesAvailable < len) {
					return; // keep waiting
				}
				
				_buffer.readBytes(_content, 0, len);
			}
			
			buffer.position = buffer.length - _buffer.bytesAvailable;
			
			_pos = 0;
			_buffer = new ByteArray();
			
			dispatchEvent(new HTTPStatusEvent(HTTPStatusEvent.HTTP_STATUS, { status: _status, explain: _explain, data: _content }));
		}
		
		protected function _parseStatusLine(buffer:ByteArray):void {
			var enum:Object = {
				sw_start: 0,
				sw_version: 1,
				sw_spaces_before_status: 2,
				sw_status: 3,
				sw_spaces_before_explain: 4,
				sw_explain: 5,
				sw_almost_done: 6
			};
			
			var state:uint = _state;
			var v:String, s:String;
			
			for ( ; buffer.bytesAvailable; _pos++) {
				var ch:String = buffer.readUTFBytes(1);
				
				switch (state) {
					case enum.sw_start:
						v = ch;
						state = enum.sw_version;
						break;
					
					case enum.sw_version:
						if (ch == ' ') {
							if (v == 'HTTP/1.0') {
								_version = STU_HTTP_VERSION_10;
							} else {
								_version = STU_HTTP_VERSION_11;
							}
							state = enum.sw_spaces_before_status;
						} else {
							v += ch;
						}
						break;
					
					case enum.sw_spaces_before_status:
						s = ch;
						state = enum.sw_status;
						break;
					
					case enum.sw_status:
						if (ch == ' ') {
							_status = parseInt(s);
							state = enum.sw_spaces_before_explain;
						} else {
							s += ch;
						}
						break;
					
					case enum.sw_spaces_before_explain:
						_explain = ch;
						state = enum.sw_explain;
						break;
					
					case enum.sw_explain:
						if (ch == CR) {
							state = enum.sw_almost_done;
						} else {
							_explain += ch;
						}
						break;
					
					case enum.sw_almost_done:
						if (ch == LF) {
							_state = enum.sw_start;
							return;
						}
						break;
				}
			}
			
			_state = state;
		}
		
		protected function _parseHeaders(buffer:ByteArray):void {
			var enum:Object = {
				sw_start: 0,
				sw_name: 1,
				sw_space_before_value: 2,
				sw_value: 3,
				sw_ignore_line: 4,
				sw_almost_done: 5,
				sw_header_almost_done: 6
			};
			
			var state:uint = _state;
			var k:String, v:String;
			
			for ( ; buffer.bytesAvailable; _pos++) {
				var ch:String = buffer.readUTFBytes(1);
				
				switch (state) {
					/* first char */
					case enum.sw_start:
						if (ch == CR) {
							state = enum.sw_header_almost_done;
						} else {
							k = ch;
							state = enum.sw_name;
						}
						break;
					
					/* header name */
					case enum.sw_name:
						if (ch == ':') {
							state = enum.sw_space_before_value;
						} else {
							k += ch;
						}
						
						/* IIS may send the duplicate "HTTP/1.1 ..." lines */
						if (ch == '/' && k == 'HTTP') {
							state = enum.sw_ignore_line;
						}
						break;
					
					/* space* before header value */
					case enum.sw_space_before_value:
						switch (ch) {
							case ' ':
								break;
							case CR:
								state = enum.sw_almost_done;
								break;
							default:
								v = ch;
								state = enum.sw_value;
								break;
						}
						break;
					
					/* header value */
					case enum.sw_value:
						if (ch == CR) {
							state = enum.sw_almost_done;
						} else {
							v += ch;
						}
						break;
					
					/* ignore header line */
					case enum.sw_ignore_line:
						if (ch == LF) {
							state = enum.sw_start;
						}
						break;
					
					/* end of header line */
					case enum.sw_almost_done:
						if (ch == LF) {
							k = k.toLowerCase();
							_headers[k] = v;
							state = enum.sw_start;
						} else {
							dispatchEvent(new HTTPStatusEvent(HTTPStatusEvent.ERROR, { text: 'Failed to parse http header line.' }));
							return;
						}
						break;
					
					/* end of header */
					case enum.sw_header_almost_done:
						if (ch == LF) {
							_state = enum.sw_start;
							_done = true;
							return;
						} else {
							dispatchEvent(new HTTPStatusEvent(HTTPStatusEvent.ERROR, { text: 'Failed to parse http headers.' }));
							return;
						}
						break;
				}
			}
			
			_state = state;
		}
		
		
		public function get version():uint {
			return _version;
		}
		
		public function get status():uint {
			return _status;
		}
		
		public function get explain():String {
			return _explain;
		}
		
		public function get headers():Object {
			return _headers;
		}
		
		public function get content():ByteArray {
			return _content;
		}
	}
}