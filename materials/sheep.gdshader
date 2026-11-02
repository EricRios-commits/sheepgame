shader_type spatial;

//0: Idle (Do nothing)
//1: Walking
uniform int animation_state = 0;

uniform float speed = 4.0f;
//this can be modulated from code depending on the speed
uniform float amplitude = 1;

//EXPLAINATION
//The sheep model has vertex colors that are used to "subdivide" the model into 
//"parts". Each part is then animated slightly differently

const vec3 back_left_color = vec3(1,0,0);
const vec3 back_left_leg = vec3(0.198, 0.37, -0.324);
const vec3 front_left_color = vec3(0,1,0);
const vec3 front_left_leg = vec3(0.198, 0.37, 0.324);
const vec3 back_right_color = vec3(0,0,1);
const vec3 back_right_leg = vec3(-0.198, 0.37, -0.324);
const vec3 front_right_color = vec3(0,0,0);
const vec3 front_right_leg = vec3(-0.198, 0.37, 0.324);
const float THRESHOLD = 0.2;


//Index in a matrix is M[row][column]
//Yes this should be a mat4, but since we do not care about translation 
//it can be just a mat3
mat3 rotateYZ(float angle){
	mat3 result = mat3(0.0);
	result[0][0] = 1.0;
	result[1][1] = cos(angle);
	result[1][2] = -sin(angle);
	result[2][1] = sin(angle);
	result[2][2] = cos(angle);
	return result;
}

void vertex() {
	if(animation_state == 1){
		if(length(COLOR.xyz - back_left_color) < THRESHOLD) {
			float phase = 0.0;
			float angle = amplitude * sin(speed * TIME + phase);
			vec3 translated_pos = VERTEX - back_left_leg;
			VERTEX = back_left_leg + (rotateYZ(angle) * translated_pos);
		} else if(length(COLOR.xyz - front_left_color) < THRESHOLD){
			float phase = PI / 6.0;
			float angle = amplitude * sin(speed * TIME + phase);
			vec3 translated_pos = VERTEX - front_left_leg;
			VERTEX = front_left_leg + (rotateYZ(angle) * translated_pos);
		} else if(length(COLOR.xyz - back_right_color) < THRESHOLD){
			float phase = PI * 5.0 / 6.0;
			float angle = amplitude * sin(speed * TIME + phase);
			vec3 translated_pos = VERTEX - back_right_leg;
			VERTEX = back_right_leg + (rotateYZ(angle) * translated_pos);
		} else if(length(COLOR.xyz - front_right_color) < THRESHOLD){
			float phase = PI;
			float angle = amplitude * sin(speed * TIME + phase);
			vec3 translated_pos = VERTEX - front_right_leg;
			VERTEX = front_right_leg + (rotateYZ(angle) * translated_pos);
		}
		
	}
	
	
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
