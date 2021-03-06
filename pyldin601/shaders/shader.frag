#ifdef GL_ES
precision mediump float;
#endif

varying vec2 textureCoordinate;

uniform sampler2D videoFrame;

void main()
{
	gl_FragColor = texture2D(videoFrame, textureCoordinate);
}
