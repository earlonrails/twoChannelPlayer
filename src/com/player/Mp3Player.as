package com.player {

  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.MouseEvent;
  import flash.events.ProgressEvent;
  import flash.events.TimerEvent;
  import flash.media.Sound;
  import flash.media.SoundChannel;
  import flash.media.SoundTransform;
  import flash.net.URLRequest;
  import flash.utils.Timer;
  import flash.external.ExternalInterface;

  import mx.controls.Alert;
  import mx.events.FlexEvent;

  import com.player.Mp3PlayerSkin;
  import org.osmf.events.TimeEvent;

  import spark.components.Label;
  import spark.components.SkinnableContainer;
  import spark.components.ToggleButton;
  import spark.components.mediaClasses.ScrubBar;
  import spark.components.mediaClasses.VolumeBar;
  import spark.components.VSlider;
  import spark.components.HSlider;
  import spark.events.TrackBaseEvent;

  public class Mp3Player extends SkinnableContainer {

    /**
     *  @private variables
     */
    private var _autoPlay:Boolean = false;
    private var _source:String;
    private var scrubBarMouseCaptured:Boolean;
    private var wasPlayingBeforeSeeking:Boolean;
    private var scrubBarChanging:Boolean;
    private var _volume:Number = 100;
    private var _muted:Boolean = false;

    /**
     *  @public variables
     */
    [SkinPart]
    public var playPauseButton:ToggleButton;
    [SkinPart]
    public var scrubBar:ScrubBar;
    [SkinPart]
    public var currentTimeDisplay:Label;
    [SkinPart]
    public var durationDisplay:Label;
    [SkinPart]
    public var leftChannelLabel:Label;
    [SkinPart]
    public var rightChannelLabel:Label;
    [SkinPart]
    public var channelVolumeBar:VSlider;
    [SkinPart]
    public var volumeBar:VolumeBar;

    public var mySound:Sound;
    public var myChannel:SoundChannel;
    public var soundPosition:Number = 0;
    public var isPlaying:Boolean = false;
    public var timer:Timer;
    public var rightVolume:Number = 100;
    public var leftVolume:Number = 100;

    public function Mp3Player() {
      super();

      setStyle("skinClass", Mp3PlayerSkin);
      timer = new Timer(100);
      timer.addEventListener(TimerEvent.TIMER, handleTime);
    }

    /**
     *  @public functions
     */
    public function get volume():Number {
      return _volume;
    }

    public function set volume(value:Number):void {
      _volume = value;

      if (volumeBar) volumeBar.value = value;
      if (myChannel) {
        var transform:SoundTransform = myChannel.soundTransform;
        transform.volume = (value / 100);
        myChannel.soundTransform = transform;
      }
    }

    public function get autoPlay():Boolean {
      return _autoPlay;
    }

    public function set autoPlay(value:Boolean):void {
      _autoPlay = value;

      if (validSource() && _autoPlay) {
        play();
      }
    }

    public function get source():String {
      return _source;

    }

    public function set source(value:String):void {
      _source = value;
      if (validSource()) {
        loadSound();
        if (_autoPlay) play();
      }
    }

    public function get muted():Boolean {
      return _muted;
    }

    public function set muted(value:Boolean):void {
      _muted = value;

      if (volumeBar) {
        volumeBar.muted = value;
      }

      var transform:SoundTransform = myChannel.soundTransform;
      transform.volume = muted ? 0 : (volume / 100);
      myChannel.soundTransform = transform;
    }

    public function get channelVolumeBarValue():Number {
      return channelVolumeBar.value;
    }

    public function set channelVolumeBarValue(value:Number):void {
      channelVolumeBar.value = value;
    }

    public function seekToSource(url:String, seekAhead:Number):void {
      _source = url;
      if (validSource()) {
        loadSound();
        channelVolumeBarValue = 50;
        soundPosition = seekAhead * 1000;
        updateDisplay();
        updateScrubBar();
        play();
      }
    }

    public function setChannelLabels(rightVal:String, leftVal:String):void {
      leftChannelLabel.text = leftVal;
      rightChannelLabel.text = rightVal;
    }

    public function adjustPan(panVolume:Number):void {
      var transform:SoundTransform = new SoundTransform();
      var baseVolume:Number = (volume / 100);
      var pan:Number;

      if (panVolume > 50) {
        pan = (( panVolume / 50 ) - 50);
      } else if (panVolume < 50) {
        pan = (( panVolume - 50 ) / 50);
      } else {
        pan = 0;
      }
      transform.pan = pan;
      transform.volume = baseVolume;
      myChannel.soundTransform = transform;
    }

    public function adjustChannelVolume(channelVolume:Number):void {
      var transform:SoundTransform = new SoundTransform();
      var baseVolume:Number = (volume / 100);

      if (channelVolume > 50) {
       //ADJUST LEFT CHANNEL
       leftVolume = Math.abs(( channelVolume - 100 ) / 50);
       rightVolume = 1;
      } else {
       // ADUJUST RIGHT CHANNEL
       rightVolume = Math.abs(( channelVolume / 50 ));
       leftVolume = 1;
      }
      transform.leftToLeft = leftVolume;
      transform.rightToRight = rightVolume;
      transform.volume = baseVolume;
      myChannel.soundTransform = transform;
    }

    public function validSource():Boolean {
      return (_source && _source != "");
    }

    public function loadSound():void {
      if (myChannel) myChannel.stop();
      if (validSource()) {
        mySound = new Sound();
        mySound.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
        mySound.addEventListener(ProgressEvent.PROGRESS, progressHandler);

        var request:URLRequest = new URLRequest(_source);
        mySound.load(request);
      }

      isPlaying = false;
      timer.stop();

      if (playPauseButton) playPauseButton.selected = false;
      updateDisplay();
      updateScrubBar();
    }

    public function playSound(event:Event):void {
      if (isPlaying) {
        pause();
        if ((mySound.length-soundPosition)<500) rewind();
      } else {
        play();
      }
    }

    public function play():void {
      myChannel = mySound.play(soundPosition);
      volume = _volume;

      if (playPauseButton) {
        playPauseButton.selected = true;
      }
      isPlaying = true;
      timer.start();
    }

    public function pause():void {
      if (myChannel) {
        soundPosition = myChannel.position;
        myChannel.stop();
      }
      if (playPauseButton) playPauseButton.selected = false;
      isPlaying = false;
      timer.stop();
    }

    public function rewind():void {
      soundPosition = 0;
      updateScrubBar();
      updateDisplay();

      if (isPlaying) myChannel.stop();
    }

    public function seek(time:Number):void {
      soundPosition = time;
      if (isPlaying) {
        myChannel.stop();
        myChannel = mySound.play(soundPosition);
        volume = _volume;
      }
    }

    public function getTrackPosition():Number {
      return myChannel.position;
    }

    /**
     *  @private functions
     */
    private function errorHandler(event:IOErrorEvent):void {
      Alert.show("Unable to load mp3");
    }

    private function progressHandler(event:ProgressEvent):void {
      updateDisplay();
      updateScrubBar();
    }

    private function updateScrubBar():void {
      if (!scrubBar || !mySound) return;

      if (!scrubBarMouseCaptured && !scrubBarChanging) {
        scrubBar.minimum = 0;
        scrubBar.maximum = mySound.length/1000;
        scrubBar.value = soundPosition/1000;
      }

      if (mySound.bytesTotal == 0) {
        scrubBar.loadedRangeEnd = 0;
      } else {
        scrubBar.loadedRangeEnd = (mySound.bytesLoaded/mySound.bytesTotal)*scrubBar.maximum;
      }
    }

    private function updateDisplay():void {
      if (currentTimeDisplay) currentTimeDisplay.text = formatTimeValue(soundPosition/1000);
      if (durationDisplay) durationDisplay.text = formatTimeValue(mySound.length/1000);
    }

    private function handleTime(event:TimerEvent):void {
      if (!isPlaying) return;
      soundPosition = myChannel.position;
      updateDisplay();
      updateScrubBar();
    }

    private function scrubBarChangeStartHandler(event:Event):void {
      scrubBarChanging = true;
    }

    private function scrubBarThumbPressHandler(event:TrackBaseEvent):void {
      scrubBarMouseCaptured = true;
      if (isPlaying){
        pause();
        wasPlayingBeforeSeeking = true;
      }
    }

    private function scrubBarThumbReleaseHandler(event:TrackBaseEvent):void {
      scrubBarMouseCaptured = false;
      if (wasPlayingBeforeSeeking) {
        play();
        wasPlayingBeforeSeeking = false;
      }
    }

    private function scrubBarChangeHandler(event:Event):void {
      seek(scrubBar.value * 1000);
    }

    private function scrubBarChangeEndHandler(event:Event):void {
      scrubBarChanging = false;
    }

    private function volumeBarChangeHandler(event:Event):void {
      if (volume != volumeBar.value) volume = volumeBar.value;
    }

    private function volumeBarMutedChangeHandler(event:FlexEvent):void {
      if (muted != volumeBar.muted) muted = volumeBar.muted;
    }

    private function channelVolumeBarChangeHandler(event:Event):void {
      var channelVolumeAmount:Number = event.currentTarget.value;
      adjustChannelVolume(channelVolumeAmount);
    }

    private function consoleLog(message:String):void {
      if (ExternalInterface.available){
        message = "[FlashMp3PlayerAS Log] " + message;
        ExternalInterface.call("console.log", message);
      }
    }

    /**
     *  @protected functions
     */
    override protected function partAdded(partName:String, instance:Object):void {
      super.partAdded(partName, instance);
      switch (instance) {
        case playPauseButton:
          playPauseButton.addEventListener(MouseEvent.CLICK, playSound);
          playPauseButton.selected = isPlaying;
          break;
        case scrubBar:
          // add thumbPress and thumbRelease so we pause the video while dragging
          scrubBar.addEventListener(TrackBaseEvent.THUMB_PRESS, scrubBarThumbPressHandler);
          scrubBar.addEventListener(TrackBaseEvent.THUMB_RELEASE, scrubBarThumbReleaseHandler);
          // add change to actually seek() when the change is complete
          scrubBar.addEventListener(Event.CHANGE, scrubBarChangeHandler);
          // add changeEnd and changeStart so we don't update the scrubbar's value
          // while the scrubbar is moving around due to an animation
          scrubBar.addEventListener(FlexEvent.CHANGE_END, scrubBarChangeEndHandler);
          scrubBar.addEventListener(FlexEvent.CHANGE_START, scrubBarChangeStartHandler);
          updateScrubBar();
          break;
        case volumeBar:
          volumeBar.addEventListener(Event.CHANGE, volumeBarChangeHandler);
          volumeBar.addEventListener(FlexEvent.MUTED_CHANGE, volumeBarMutedChangeHandler);
          volumeBar.muted = muted;
          break;
        case channelVolumeBar:
          channelVolumeBar.addEventListener(Event.CHANGE, channelVolumeBarChangeHandler);
          break;

      }
    }

    protected function formatTimeValue(value:Number):String {
      // default format: hours:minutes:seconds
      value = Math.round(value);
      var hours:uint = Math.floor(value/3600) % 24;
      var minutes:uint = Math.floor(value/60) % 60;
      var seconds:uint = value % 60;

      var result:String = "";
      if (hours != 0) result = hours + ":";

      if (result && minutes < 10) {
        result += "0" + minutes + ":";
      } else {
        result += minutes + ":";
      }

      if (seconds < 10) {
        result += "0" + seconds;
      } else {
        result += seconds;
      }

      return result;
    }

  }
}
