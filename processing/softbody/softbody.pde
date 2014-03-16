/**********************************************************************
 *Copyright (c) 2014, Stephen Macke
 *All rights reserved.
 *
 *Redistribution and use in source and binary forms, with or without
 *modification, are permitted provided that the following conditions are met: 
 *
 *1. Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer. 
 *2. Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution. 
 *
 *THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 *ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 *ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *The views and conclusions contained in the software and documentation are those
 *of the authors and should not be interpreted as representing official policies, 
 *either expressed or implied, of the FreeBSD Project.
 */

/**********************************************************************
 *Pressurized soft body physics simulator in two dimensions.
 *
 *Author: Stephen Macke. 
 *
 *Many of the math and physics calculations are based on a
 *paper by Maciej Matyka. See
 *http://panoramix.ift.uni.wroc.pl/~maq/soft2d/howtosoftbody.pdf
 **********************************************************************
 */	
//Constants

//Frames per second
int    FPS			  = 120;

int    NUM_POINTS     = 20;        //20 by default, 50 works also

int    NUM_SPRINGS    = NUM_POINTS;

int    LENGTH         = 75;

int    WIDTH          = 1200;
int    HEIGHT         = 500;
float  RADIUS         = 190.0;
float  R2             = pow(RADIUS,2);

float MASS           = 1.0;
float BALL_RADIUS    = 0.516;    //0.516 by default

//Spring constants
float KS             = 755.0;    //755 by default
float KD             = 35.0;        //35.0 by default

//Gravity force and user applied force
float GY             = 110.0;     //110.0 by default
float FAPP           = 110.0;

//Time interval for numeric integration
float DT             = 0.01;    //0.005 by default

//Pressure to be reached before ball is at full capacity
float FINAL_PRESSURE = 70000;     //70000 by default

//Tangential and normal damping factors
float TDF = 0.99;                         //0.95 by default, 1.0 works, 1.01 is cool
// A TDF of 1.0 means frictionless boundaries.
// If some energy were not lost due to the ball's
// spring-damping, the ball could continue
// traveling forever without any force.

float NDF = 0.1;                   //0.1  by default

float pressure;

Points myPoints;
Springs mySprings;

boolean upArrow = false;
boolean downArrow = false;
boolean leftArrow = false;
boolean rightArrow = false;

boolean mouseP = false;


/**************************************************
 * Initialize the applet by declaring new objects
 * of type Points and Springs.
 * 
 * Also, set things up for an animation. 
 **************************************************/	 
void setup() {
	size(WIDTH, HEIGHT);
 	frameRate(60);

	myPoints = new Points(NUM_POINTS);
	mySprings = new Springs(NUM_SPRINGS);

	createBall();
}


void draw() {
	fill(255);
	background(255);

	stroke(0);
	ellipse(WIDTH/2, HEIGHT/2, 2*RADIUS, 2*RADIUS);

	fill(#FF0000);  //pure red
	noStroke();
	beginShape();
	for (int i=0; i<myPoints.x.length; i++) {
		vertex(myPoints.x[i], myPoints.y[i]);
	}
	endShape(CLOSE);

	idle();
	idle(); // get 2 bits of work done for 1 frame
	// better than just increasing DT, since we still converge
	
	stroke(0);
	if(mouseP) {
		line(mouseX, mouseY, myPoints.x[0], myPoints.y[0]);
	}
	
}



/**************************************************
 * Here are some fun functions for user-input.
 **************************************************/
void keyPressed() {
	if (key==CODED) {
		switch (keyCode) {
			case UP: upArrow=true; break;
			case DOWN: downArrow=true; break;
			case LEFT: leftArrow=true; break;
			case RIGHT: rightArrow=true; break;
		}
	}
}

void keyReleased() {
	if (key==CODED) {
		switch (keyCode) {
			case UP: upArrow=false; break;
			case DOWN: downArrow=false; break;
			case LEFT: leftArrow=false; break;
			case RIGHT: rightArrow=false; break;
		}
	}
}

void mousePressed() {
	mouseP = true;
}

void mouseReleased() {
	mouseP = false;
}

/**************************************************
 * In these next lines are some functions to help
 * set up the points and springs for the ball as
 * well as all of the functions to do the physics.
 **************************************************/

/**************************************************
 * Function to set up the springs.
 **************************************************/
void addSpring(int i, int j, int k) {
	mySprings.spring1[i] = j;
	mySprings.spring2[i] = k;

	mySprings.length[i] = sqrt( (myPoints.x[j] - myPoints.x[k]) * (myPoints.x[j] - myPoints.x[k])
	+ (myPoints.y[j] - myPoints.y[k]) * (myPoints.y[j] - myPoints.y[k]));
}

/**************************************************
 * Simple function to lay out the points of the
 * ball in a circle, then create springs between
 * these points.
 **************************************************/
void createBall() {
	for (int i = 0; i < NUM_POINTS; i++) {
		myPoints.x[i] = BALL_RADIUS * cos(i * 2 * PI / NUM_POINTS) + WIDTH/2;
		myPoints.y[i] = BALL_RADIUS * sin(i * 2 * PI / NUM_POINTS) + HEIGHT/4;
	}


	for (int i = 0; i < NUM_POINTS - 1; i++) {
		addSpring(i, i, i + 1);
	}
	addSpring(NUM_POINTS - 1, NUM_POINTS - 1, 0);
}

/**************************************************
 * This function does a large part of the physics
 * calculations.  It starts by adding gravity and
 * checking for inputs, and then by taking into
 * account spring force and pressure force.
 **************************************************/
void accumulateForces() {
	float x1, x2, y1, y2;
	float r12d;
	float vx12;
	float vy12;
	float f;
	float fx0, fy0;
	float volume = 0;
	float pressurev;

	/**************************************************
	 * Check for keyboard inputs and add gravitational 
	 * force.
	 **************************************************/
	for (int i = 0; i < NUM_POINTS; i++) {
		myPoints.fx[i] = 0;
		myPoints.fy[i] = (pressure - FINAL_PRESSURE) >= 0 ? GY*MASS : 0;

		if(upArrow)
			myPoints.fy[i] = -FAPP*MASS;
		if(rightArrow)
			myPoints.fx[i] = FAPP*MASS;
		if(leftArrow)
			myPoints.fx[i] = -FAPP*MASS;
		if (downArrow)
			myPoints.fy[i] = FAPP*MASS;
		if(leftArrow && rightArrow)
			myPoints.fx[i] = 0.0;
		if(upArrow && downArrow)
			myPoints.fy[i] = 0.0;
	}

	/**************************************************
	 * Check for mouse inputs.
	 **************************************************/
	if(mouseP) {
		x1 = myPoints.x[0];
		y1 = myPoints.y[0];
		x2 = mouseX;
		y2 = mouseY;

		r12d = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
		f = (r12d - 2.2) * 22 + (myPoints.vx[0] * (x1 - x2) + myPoints.vy[0] * (y1 - y2)) * 54 / r12d;

		fx0 = ((x1 - x2) / r12d ) * f;
		fy0 = ((y1 - y2) / r12d ) * f;

		myPoints.fx[0] -= fx0;
		myPoints.fy[0] -= fy0;
	}

	/**************************************************
	 * Calculate force due to each spring.
	 **************************************************/
	for (int i = 0; i < NUM_SPRINGS; i++) {
		x1 = myPoints.x[mySprings.spring1[i]];
		x2 = myPoints.x[mySprings.spring2[i]];
		y1 = myPoints.y[mySprings.spring1[i]];
		y2 = myPoints.y[mySprings.spring2[i]];

		//Find the distance between each spring:
		r12d = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

		//Accumulate spring forces:
		if (r12d != 0) {
			vx12 = myPoints.vx[mySprings.spring1[i]] - myPoints.vx[mySprings.spring2[i]];
			vy12 = myPoints.vy[mySprings.spring1[i]] - myPoints.vy[mySprings.spring2[i]];

			f = (r12d - mySprings.length[i]) * KS + (vx12 * (x1 - x2) + vy12 * (y1 - y2)) * KD / r12d;

			fx0 = ((x1 - x2) / r12d ) * f;
			fy0 = ((y1 - y2) / r12d ) * f;

			myPoints.fx[mySprings.spring1[i]] -= fx0;
			myPoints.fy[mySprings.spring1[i]] -= fy0;

			myPoints.fx[mySprings.spring2[i]] += fx0;
			myPoints.fy[mySprings.spring2[i]] += fy0;
		}
		//Calculate normal vectors for use with finding pressure force:
		mySprings.nx[i] = -(y1 - y2) / r12d;
		mySprings.ny[i] = (x1 - x2) / r12d;
	}

	/**************************************************
	 * This uses the divergence theorem (2d version)
	 * to calculate the volume (area) of the body (which is
	 * why we needed to calculate the normal vectors
	 * previously), and then uses that to calculate
	 * pressure (since P*V = constant?).
	 * 
	 * TODO: rewrite this using Green's theorem /
	 * surveyor's formula for area
	 **************************************************/
	for (int i = 0; i < NUM_SPRINGS; i++) {
		x1 = myPoints.x[mySprings.spring1[i]];
		x2 = myPoints.x[mySprings.spring2[i]];
		y1 = myPoints.y[mySprings.spring1[i]];
		y2 = myPoints.y[mySprings.spring2[i]];

		r12d = sqrt((x1 - x2) *(x1 - x2)  +  (y1 - y2) * (y1 - y2));

		volume += 0.5 * abs(x1 - x2) * abs(mySprings.nx[i]) * (r12d);
	}
	
	for (int i = 0; i < NUM_SPRINGS; i++) {
		x1 = myPoints.x[mySprings.spring1[i]];
		x2 = myPoints.x[mySprings.spring2[i]];
		y1 = myPoints.y[mySprings.spring1[i]];
		y2 = myPoints.y[mySprings.spring2[i]];

		r12d = sqrt((x1 - x2) * (x1 - x2)  +  (y1 - y2) * (y1 - y2));

		pressurev = r12d * pressure * (1.0/volume);

		myPoints.fx[mySprings.spring1[i]] += mySprings.nx[i]*pressurev;
		myPoints.fy[mySprings.spring1[i]] += mySprings.ny[i]*pressurev;
		myPoints.fx[mySprings.spring2[i]] += mySprings.nx[i]*pressurev;
		myPoints.fy[mySprings.spring2[i]] += mySprings.ny[i]*pressurev;
	}
}

/**************************************************
 * Heun Predictor-Corrector Integration
 * (with bounds checking).
 **************************************************/
void integrateHeun() {
	float drx, dry;
	
	float fxsaved[] = new float[NUM_POINTS];
	float fysaved[] = new float[NUM_POINTS];
	
	float vxsaved[] = new float[NUM_POINTS];
	float vysaved[] = new float[NUM_POINTS];

	for (int i = 0; i < NUM_POINTS; i++) {
		fxsaved[i] = myPoints.fx[i];
		fysaved[i] = myPoints.fy[i];
		
		vxsaved[i] = myPoints.vx[i];
		vysaved[i] = myPoints.vy[i];
		
		myPoints.vx[i] += myPoints.fx[i] / MASS * DT;
		drx = myPoints.vx[i] * DT;

		myPoints.x[i] += drx;

		myPoints.vy[i] += myPoints.fy[i] / MASS * DT;
		dry = myPoints.vy[i] * DT;

		myPoints.y[i] += dry;
	}
	
	accumulateForces();
	
	for (int i=0; i<NUM_POINTS; i++) {
		myPoints.vx[i] = vxsaved[i] + (myPoints.fx[i] + fxsaved[i]) / MASS * DT/2;
		drx = myPoints.vx[i] * DT;

		myPoints.x[i] += drx;

		myPoints.vy[i] = vysaved[i] + (myPoints.fy[i] + fysaved[i]) / MASS * DT/2;
		dry = myPoints.vy[i] * DT;

		myPoints.y[i] += dry;

		/**************************************************
		 * From here, the rest of the method is devoted to
		 * boundary checking.
		 **************************************************/
	
		myPoints.x[i] = min(myPoints.x[i], WIDTH/2. + RADIUS);
		myPoints.x[i] = max(myPoints.x[i], WIDTH/2. - RADIUS);

		myPoints.y[i] = min(myPoints.y[i], HEIGHT/2. + RADIUS);
		myPoints.y[i] = max(myPoints.y[i], HEIGHT/2. - RADIUS);

		if (myPoints.x[i] + drx >  sqrt(R2 - pow(myPoints.y[i] - HEIGHT/2., 2)) + WIDTH/2. || 
			myPoints.x[i] + drx < -sqrt(R2 - pow(myPoints.y[i] - HEIGHT/2., 2)) + WIDTH/2.)
		{
			drx *= -1;                           //These are temporary until I do
			dry *= -1;                           //the math to get more exact values.

			float vx0 = myPoints.vx[i];
			float vy0 = myPoints.vy[i];

			float sinTheta = (myPoints.y[i] - HEIGHT/2.) / RADIUS;
			float cosTheta = (myPoints.x[i] - WIDTH/2.) / RADIUS;

			myPoints.vx[i] = -vx0;
			myPoints.vy[i] = -vy0;
			myPoints.vx[i] = vy0 * (-TDF * sinTheta * cosTheta - NDF * sinTheta * cosTheta) + vx0 * (TDF * sinTheta * sinTheta - NDF * cosTheta * cosTheta);
			myPoints.vy[i] = vy0 * (TDF * cosTheta * cosTheta - NDF * sinTheta * sinTheta) + vx0 * (-TDF * sinTheta * cosTheta - NDF * sinTheta * cosTheta);
		}


		if (myPoints.y[i] > HEIGHT/2. + RADIUS/2.) { // need these checks to avoid setting to wrong sign
			myPoints.y[i] = min(myPoints.y[i],  sqrt(abs(R2 - pow(myPoints.x[i] - WIDTH/2., 2))) + HEIGHT/2.);
		}
		

		if (myPoints.y[i] < HEIGHT/2. - RADIUS/2.) {
			myPoints.y[i] = max(myPoints.y[i], -sqrt(abs(R2 - pow(myPoints.x[i] - WIDTH/2., 2))) + HEIGHT/2.);
		}

		if (myPoints.x[i] > WIDTH/2. + RADIUS/2.) {
			myPoints.x[i] = min(myPoints.x[i],  sqrt(abs(R2 - pow(myPoints.y[i] - HEIGHT/2., 2))) + WIDTH/2.);
		}

		if (myPoints.x[i] < WIDTH/2. - RADIUS/2.) {
			myPoints.x[i] = max(myPoints.x[i], -sqrt(abs(R2 - pow(myPoints.y[i] - HEIGHT/2., 2))) + WIDTH/2.);
		}

	}
}

/**************************************************
 * Idle function that runs all of the physics and
 * math calculations.  At the start of the program,
 * it simulates blowing the ball up by incrementing
 * the total pressure until it reaches a specified
 * value.
 **************************************************/
public void idle() {
	accumulateForces();
	integrateHeun();

	if (pressure < FINAL_PRESSURE) {
		pressure += FINAL_PRESSURE / 300.;
	}
}


/**************************************************
 * Class for the points object.  It includes arrays
 * to describe forces, velocities, and positions
 * of the points.
 **************************************************/
class Points {
	float[] x;
	float[] y;
	float[] vx, vy;
	float[] fx, fy;

	Points(int n_pts) {
		x = new float[n_pts];
		y = new float[n_pts];
		vx = new float[n_pts];
		vy = new float[n_pts];
		fx = new float[n_pts];
		fy = new float[n_pts];
	}
}

/**************************************************
 *Class for the springs object.  It includes arrays
 * to describe point-indexes, length, and normal
 * forces of the springs.
 **************************************************/
class Springs {
	int[] spring1, spring2;
	float[] length;
	float[] nx, ny;

	Springs(int n_springs) {
		spring1 = new int[n_springs];
		spring2 = new int[n_springs];
		length = new float[n_springs];
		nx = new float[n_springs];
		ny = new float[n_springs];
	}
}

