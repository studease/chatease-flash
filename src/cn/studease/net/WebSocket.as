package cn.studease.net
{
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import cn.studease.events.WebSocketEvent;
	import cn.studease.utils.Logger;

	public class WebSocket extends EventDispatcher
	{
		public static const STU_WEBSOCKET_OPCODE_TEXT:int = 0x1;
		public static const STU_WEBSOCKET_OPCODE_BINARY:int = 0x2;
		public static const STU_WEBSOCKET_OPCODE_CLOSE:int = 0x8;
		public static const STU_WEBSOCKET_OPCODE_PING:int = 0x9;
		public static const STU_WEBSOCKET_OPCODE_PONG:int = 0xA;
		
		protected var _buffer:ByteArray;
		
		protected var _fin:uint;
		protected var _rsv1:uint;
		protected var _rsv2:uint;
		protected var _rsv3:uint;
		protected var _opcode:uint;
		protected var _mask:uint;
		protected var _payload_len:uint;
		protected var _extended:uint;
		protected var _masking_key:Vector.<uint>;
		protected var _payload_data:ByteArray;
		
		protected var _state:uint;
		protected var _pos:uint;
		
		
		public function WebSocket()
		{
			_buffer = new ByteArray();
			_buffer.endian = Endian.BIG_ENDIAN;
			
			_masking_key = new Vector.<uint>(4);
			_payload_data = new ByteArray();
			
			_state = 0;
			_pos = 0;
		}
		
		public function parse(buffer:ByteArray):void {
			if (buffer.bytesAvailable == 0) {
				return;
			}
			
			buffer.readBytes(_buffer, _buffer.length);
			
			parseFrames(_buffer);
			
			// cache uncomplete bytes
			var ba:ByteArray = new ByteArray();
			if (_buffer.bytesAvailable) {
				_buffer.readBytes(ba);
			}
			
			_pos = 0;
			_buffer = ba;
		}
		
		protected function parseFrames(buffer:ByteArray):void {
			var enum:Object = {
				sw_fin: 0,
				sw_mask: 1,
				sw_extended_2: 2,
				sw_extended_8: 3,
				sw_masking_key: 4,
				sw_payload_data: 5
			};
			
			var state:uint = _state;
			var byte:uint;
			
			for ( ; buffer.bytesAvailable; _pos++) {
				switch (state) {
					case enum.sw_fin:
						byte = buffer.readUnsignedByte();
						_fin  = (byte >> 7) & 0x1;
						_rsv1 = (byte >> 6) & 0x1;
						_rsv2 = (byte >> 5) & 0x1;
						_rsv3 = (byte >> 4) & 0x1;
						_opcode = byte & 0xF;
						state = enum.sw_mask;
						break;
					
					case enum.sw_mask:
						byte = buffer.readUnsignedByte();
						_mask = (byte >> 7) & 0x1;
						_payload_len = byte & 0x7F;
						if (_payload_len == 126) {
							state = enum.sw_extended_2;
						} else if (_payload_len == 127) {
							state = enum.sw_extended_8;
						} else {
							_extended = _payload_len;
							state = _mask ? enum.sw_masking_key : enum.sw_payload_data;
						}
						break;
					
					case enum.sw_extended_2:
						if (buffer.bytesAvailable < 2) { // keep waiting
							Logger.debug('Extended 2 not complete yet!');
							_state = state;
							return;
						}
						
						_extended = buffer.readUnsignedShort();
						_pos += 1;
						state = _mask ? enum.sw_masking_key : enum.sw_payload_data;
						break;
					
					case enum.sw_extended_8:
						if (buffer.bytesAvailable < 8) { // keep waiting
							Logger.debug('Extended 8 not complete yet!');
							_state = state;
							return;
						}
						
						_extended = buffer.readUnsignedInt();
						if (_extended) {
							dispatchEvent(new WebSocketEvent(WebSocketEvent.ERROR, { text: 'Payload data length out of range!' }));
							return;
						}
						
						_extended = buffer.readUnsignedInt();
						_pos += 7;
						state = _mask ? enum.sw_masking_key : enum.sw_payload_data;
					break;
					
					case enum.sw_masking_key:
						if (buffer.bytesAvailable < 4) { // keep waiting
							Logger.debug('Masking key not complete yet!');
							_state = state;
							return;
						}
						
						_masking_key[0] = buffer.readUnsignedByte();
						_masking_key[1] = buffer.readUnsignedByte();
						_masking_key[2] = buffer.readUnsignedByte();
						_masking_key[3] = buffer.readUnsignedByte();
						_pos += 3;
						state = enum.sw_payload_data;
						break;
					
					case enum.sw_payload_data:
						if (buffer.bytesAvailable < _extended) { // keep waiting
							Logger.debug('Payload data not complete yet!');
							_state = state;
							return;
						}
						
						buffer.readBytes(_payload_data, 0, _extended);
						
						switch (_opcode) {
							case STU_WEBSOCKET_OPCODE_TEXT:
							case STU_WEBSOCKET_OPCODE_BINARY:
								if (_mask) {
									for (var i:uint = 0; i < _extended; i++) {
										_payload_data[i] ^= _masking_key[i % 4];
									}
								}
								
								Logger.debug('Payload data: ' + _payload_data.toString());
								break;
							case STU_WEBSOCKET_OPCODE_CLOSE:
								Logger.debug('close frame.');
								break;
							case STU_WEBSOCKET_OPCODE_PING:
								Logger.debug('ping frame.');
								break;
							case STU_WEBSOCKET_OPCODE_PONG:
								Logger.debug('pong frame.');
								break;
							default:
								break;
						}
						
						dispatchEvent(new WebSocketEvent(WebSocketEvent.FRAME_DATA, { opcode: _opcode, data: _payload_data }));
						
						_payload_data = new ByteArray();
						state = enum.sw_fin;
					break;
				}
			}
			
			_state = state;
		}
		
		public static function encode(text:String):ByteArray {
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.BIG_ENDIAN;
			
			var tmp:ByteArray = new ByteArray();
			tmp.writeUTFBytes(text);
			
			var len:uint = tmp.length;
			if (len < 126) {
				ba.writeByte(0x81);
				ba.writeByte(0x80 | len);
			} else if (len < 65536) {
				ba.writeByte(0x81);
				ba.writeByte(0xFE);
				ba.writeShort(len);
			} else {
				ba.writeByte(0x81);
				ba.writeByte(0xFF);
				ba.writeUnsignedInt(0);
				ba.writeUnsignedInt(len);
			}
			
			ba.writeUnsignedInt(0);
			ba.writeBytes(tmp);
			
			return ba;
		}
	}
}