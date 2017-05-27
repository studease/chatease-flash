package
{
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.external.ExternalInterface;
	import flash.system.Security;
	
	import cn.studease.api.API;
	import cn.studease.controller.Controller;
	import cn.studease.model.Config;
	import cn.studease.model.Model;
	import cn.studease.utils.Logger;
	import cn.studease.view.View;

	public class Main extends Sprite implements API
	{
		protected var _model:Model;
		protected var _view:View;
		protected var _controller:Controller;
		
		protected var _setupDone:Boolean;
		
		
		public function Main()
		{
			Security.allowDomain("*");
			
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.stageFocusRect = false;
			stage.color = 0x000000;
			
			try {
				this.addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
			} catch (err:Error) {
				_onAddedToStage();
			}
		}
		
		private function _onAddedToStage(e:Event = null):void {
			try {
				this.removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
			} catch (err:Error) {
				/* void */
			}
			
			if (!ExternalInterface.available) {
				Logger.error('ExternalInterface not available!');
				return;
			}
			
			ExternalInterface.addCallback('setup', _setup);
			
			try {
				var id:String = this.loaderInfo.parameters.id;
				Logger.log('Param id: ' + id);
				
				ExternalInterface.call(''
					+ 'function() {'
						+ 'var chat = chatease("' + id + '");'
						+ 'if (chat) {'
							+ 'chat.onSWFLoaded();'
						+ '}'
					+ '}');
			} catch (err:Error) {
				Logger.error('Failed to call external interface "setup"!');
			}
			
			/*_setup({
				id: 'chat',
				url: 'ws://192.168.4.248:6688/ch1?token=123456',
				debug: true
			});
			connect();*/
		}
		
		private function _setup(cfg:Object):void {
			if (!_setupDone) {
				_model = new Model(cfg);
				_view = new View(_model);
				_controller = new Controller(_model, _view);
				
				this.addChild(_view.element);
				
				ExternalInterface.addCallback('connect', connect);
				ExternalInterface.addCallback('send', send);
				ExternalInterface.addCallback('close', close);
				
				_setupDone = true;
				
				Logger.log('Setup chatease.flash done!');
			}
		}
		
		
		public function get version():String {
			return _model.config.version;
		}
		
		public function get config():Config {
			return _model.config;
		}
		
		public function get state():String {
			return _model.state;
		}
		
		
		public function connect():void {
			_controller.connect();
		}
		
		public function send(text:String):void {
			_controller.send(text);
		}
		
		public function close():void {
			_controller.close();
		}
	}
}