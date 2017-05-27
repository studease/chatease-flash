package cn.studease.view
{
	import flash.display.DisplayObject;
	import flash.events.EventDispatcher;
	
	import cn.studease.model.Model;
	
	import fl.controls.Label;

	public class View extends EventDispatcher
	{
		protected var _model:Model;
		protected var _label:Label;
		
		
		public function View(model:Model)
		{
			_model = model;
			
			_label = new Label();
			_label.text = 'What are you looking for?';
		}
		
		
		public function get element():DisplayObject {
			return _label;
		}
	}
}