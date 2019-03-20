/**
 * Models a Job for a CPU.
 *
 * @author Kyle Burke <https://github.com/paithan>
 */
use Time;

//Job class
class Job {

    //Timer used to track the waiting time and latency.
    var timer: Timer;
    
    //Expected running time in seconds.
    var length : real;
    
    //The amount of time between when the job is created and starts running.
    var waitTime : real;
    
    //The time between when the job is created and finishes running.
    var latency : real;
    
    //Whether this is still waiting.
    var isWaiting : bool;
    
    //Whether this has finished running.
    var isFinished : bool;
    
    //Initializer.  Sets the fields and starts the clock 
    proc init(jobLength : real) {
        this.timer = new Timer();
        this.length = jobLength;
        this.isWaiting = true;
        this.isFinished = false;
        if (jobLength == 0) {
            writeln("Created a job with zero length!");
        }
        this.timer.start();
        this.complete();
        //writeln("Just created job with length: " + this.length + " seconds!");
    }
    
    //Returns the expected running time, in seconds.
    proc getLength() {
        return this.length;
    }
    
    //the process stops waiting and starts running!
    proc startRunning() {
        this.isWaiting = false;
        this.waitTime = this.timer.elapsed();
    }
    
    //the process stops running.
    proc stopRunning() {
        latency = this.timer.elapsed();
        this.isFinished = true;
        /*  Took this out because it was causing problems!
        sleep(.1);
        try {
            this.timer.stop();
        } catch {
            writeln("Timer couldn't stop!  elapsed time: " + timer.elapsed + "!!!!!!!!!!!");
        }*/
    }
    
    //Returns whether this job has completed running.
    proc isDone() : bool {
        return this.isFinished;
    }
    
    //Returns the wait time of this Job. 
    proc getWaitTime() : real {
        if (this.isWaiting) {
            return this.timer.elapsed();
        } else {
            return waitTime;
        }
    }
    
    //Returns the latency of this job.
    proc getLatency() : real {
        if (this.isFinished) {
            return latency;
        } else {
            return this.timer.elapsed();
        }
    }
    
    //prints this out
    proc writeThis(writer) {
        writer.write("Job that will take about " + this.getLength() + "s.");
    }  
} //end of Job class
