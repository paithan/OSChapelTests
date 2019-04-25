/*******************************
 * Tests Scheduler class.
 *
 * Usage:
 * $ chpl -MteamNameProject2 testScheduler.chpl
 * $ ./testScheduler
 *
 * Inside the folder teamNameProject2 there should be three files:
 * * Semaphore.chpl
 * * BlockingQueue.chpl
 * * Scheduler.chpl
 * 
 * CPU.chpl and Job.chpl should not be in the folder!
 *
 * Author: Kyle Burke <https://github.com/paithan>
 */
use Time;
use Random;
use BlockingQueue;
use Job;
use Scheduler;
use CPU;

//configurable constants
config const n = 100000; //number of jobs to run per CPU
config const c = 3; //number of CPUs
config const t : real = .001; //maximum length of a single job
config const v : bool = true; //whether or not to print out the details while running
config const m : string = "all"; //which tests to run (this doesn't work right now, so just leave it alone.)
config const tr : int = 0; //which trial to run. 0 is maximum, 1 is average, 2 is hybrid

//better names
var numberJobs = n; //the number of jobs per CPU
var numCPUs = c;
var maxTime = t;
var printAll = v;
var testMode = m;

//scale for the number of CPUs
numberJobs = (numberJobs * numCPUs);


//number of different tests I'm going to run
var numTests = 3;

var trialsDomain = {0..numTests-1};

var modes : [trialsDomain] string;
modes = ("maximum", "average", "hybrid");

var scoresDomain = {0..6};
var scores : [scoresDomain] int;
//scores = (35, 30, 25, 20, 15, 10, 5);
scores = (70, 60, 50, 40, 30, 20, 10);

var baseTime = maxTime; // / numCPUs;

var maxGoals, avgGoals, hybridGoals : [scores.domain] real;
//maxGoals = (175 * maxTime, 350 * maxTime, 700*maxTime, 1500*maxTime, 3000*maxTime, 6000*maxTime, 12000*maxTime); //old from Chapel v16
maxGoals = (5000 * baseTime, 7500 * baseTime, 12000 * baseTime, 19000 * baseTime, 30000 * baseTime, 60000 * baseTime, 120000 * baseTime);
//avgGoals = (41 * maxTime, 52 * maxTime, 65 * maxTime, 85 * maxTime, 100*maxTime, 120*maxTime, 150*maxTime); //old from Chapel v16
avgGoals = (300 * baseTime, 450 * baseTime, 600 * baseTime, 1000 * baseTime, 1500 * baseTime, 2500 * baseTime, 5000 * baseTime);
//hybridGoals = (500*maxTime, 510*maxTime, 520*maxTime, 540*maxTime, 570*maxTime, 610*maxTime, 650*maxTime); //old from Chapel v16
hybridGoals = (31000 * baseTime, 34000 * baseTime, 38500 * baseTime, 45500 * baseTime, 55000 * baseTime, 75000 * baseTime, 100000 * baseTime);

var things : [0..2, 0..3] real;

//var goals : [scoresDomain] real;
//goals[0] = maxGoals;
//goals[1] = avgGoals;
//goals[2] = hybridGoals;

//var efficiencyGoals : [trialsDomain] real;
//efficiencyGoals = (30.5, 9.5, 50);


var results : shared TestResult;

trialsDomain = {tr..tr}; //have to reset the trialsDomain because I'm getting lots of errors, probably due to ownership issues.

for i in trialsDomain {
    var nilResult : shared TestResult;
    var mode = modes[i];
    if (testMode == "all" || testMode == mode) {
        writeln("About to run the " + mode + " test.");//  Press Enter to continue.");
        //stdin.readln();
        sleep(2);
        var trialsIndex : int;
        trialsIndex = i;
        //var efficiencyGoal : real;
        //efficiencyGoal = efficiencyGoals[i];
        var xx : int;
        xx = numCPUs;
        var yy : string;
        yy = mode;
        var zz : int;
        zz = numberJobs;
        //runTest(mode, numCPUs, numJobs, efficiencyGoal);
        var newResult = runTest(numCPUs, numberJobs, i);

        if (results == nilResult) {
            results = newResult;
        } else {
            results = new shared TestResult(results, newResult);
        }
    }
    // I copied over the code from runTest because I can't figure out what's going on...
}

writeln(results);



proc runTest(numCPUs : int, numberJobs : int, modeIndex : int) : shared TestResult {
    
    var done = false;
    
    var jobIds = {0 .. numberJobs - 1};
    var firstRoundSize = min(numberJobs / 3, max(800, 50 * numCPUs)); // the number of jobs to be thrown into the already-waiting queue.
    
    writeln("Going to run a test with ", numCPUs, " and ", numberJobs, " jobs.");
    writeln("We're going to first load ", firstRoundSize, " jobs into the queue, then deliver the remaining jobs at random intervals.");
    
    var firstRoundJobIds = jobIds # firstRoundSize;
    var remainingJobIds = {firstRoundSize .. numberJobs - 1};
    
    var rng = new owned NPBRandomStream(real);

    var mode = modes[modeIndex];

    writeln("Phase: Setting up the goals for this test.");
    var goals : [scoresDomain] real = maxGoals;
    if (mode == "average") {
        goals = avgGoals;
    } else if (mode == "hybrid") {
        goals = hybridGoals;
    }
    var efficiencyGoals = goals[modeIndex];

    var jobs = new shared JobGroup();
    writeln("Phase: Creating the scheduler...");
    var scheduler = new owned Scheduler(mode);
    writeln("Phase: Scheduler created!");

    //ask the scheduler how big of a queue it wants.
    var queueCapacity = scheduler.getOutputQueueCapacity(numCPUs);

    //create the queue between scheduler and CPUs
    writeln("Phase: Creating the BlockingQueue between the scheduler and the CPUs.");
    var schedulerToCPUs = new shared BlockingQueue(shared Job, queueCapacity);
    scheduler.setOutputQueue(schedulerToCPUs);

    //create the cpus
    writeln("Phase: Creating the CPUs.");
    var cpusDomain = {0..numCPUs-1};
    var cpus : [cpusDomain] shared CPU;
    forall i in cpus.domain {
        cpus[i] = new shared CPU(schedulerToCPUs, i : string, printAll);
        begin{
            cpus[i].start();
        }
    }
    
    //this is the queue that will add things to the scheduler
    var newJobsToScheduler = new shared BlockingQueue(shared Job, numberJobs);
    
    


    //Throw a first round of jobs in it.  There's no waiting between creation of jobs.
    writeln("Phase: Adding the first round of jobs.");
    forall i in firstRoundJobIds {
        var nextFactor = rng.getNext();
        //writeln("nextFactor: ", nextFactor);
        //writeln("maxTime: ", maxTime);
        var jobLength = nextFactor * maxTime;
        //writeln("jobLength: ", jobLength);
        var job = new shared Job(jobLength, i);
        jobs.add(job); //add it to the JobGroup
        newJobsToScheduler.add(job); 
    }
    
    //this thread to regularly print out how many jobs are waiting and how many have completed
    writeln("Phase: Launching a thread to periodically point out how many jobs are still waiting.");
    begin with (ref done) {
        while (!done) {
            writeln(scheduler.getNumJobsWaiting() + " jobs waiting; " + getNumJobsProcessed(cpus) + " jobs completed.");
            sleep(max(.5, maxTime * 20));
        }
    }
    
    
    //this thread pulls jobs out of the queue and puts them into the scheduler.
    //at this point, the scheduler should start doing things.
    writeln("Phase: Launching the thread to take jobs from the input queue and put them into the scheduler.");
    begin {
        for i in 1..numberJobs {
            /*
            if (i % 100 == 0) {
                writeln("added job ", i);
            }*/
            var job : shared Job;
            job = newJobsToScheduler.remove();
            scheduler.addJob(job);
        }
    }

    //Throw the rest of the jobs at the Scheduler
    //for each cpu, create a separate thread to add jobs
    writeln("Phase: Launch the threads to add newly-generated jobs to the scheduler.");
    var numRemainingJobs = numberJobs - firstRoundSize; //necessary?  or take out.
    coforall i in cpusDomain {
        writeln("Phase: Launching the thread to generate new jobs for CPU #", i, ".");
        for jobId in remainingJobIds by numCPUs align i {
        //for j in 1..(numRemainingJobs / numCPUs) {
            var job = new shared Job(rng.getNext() * maxTime, jobId);
            jobs.add(job);
            newJobsToScheduler.add(job);
            //begin { scheduler.addJob(job); } //don't wait on this
            
            //wait some time before adding the next job
            //sleep(.96 * (rng.getNext() * maxTime));
            sleep(.44 * maxTime - .000008); //the .000008 is about the time the loop takes.
        }
        writeln("Phase: Done generating jobs for CPU #", i, ".");
    }

    //get the appropriate score
    writeln("Phase: Calculating scores!");
    var efficiencyMeasure = jobs.reportStats(modeIndex);
    var score = 0;
    var maxScore = scores[0];
    var goalMade = "none";

    for i in scores.domain {
        var nextScore = scores[i];
        var goal = goals[i];
        if (efficiencyMeasure < goal) {
            score = nextScore;
            goalMade = goal + "s";
            break;
        }
    }
    writeln("Phase: Scores calculated!");
    var description = "Results of " + mode + " test:\nRecorded time: " + efficiencyMeasure + "s.\nBest goal passed: " + goalMade + "\nPoints earned: " + score + "/" + maxScore + "\n\n";

    writeln(description);
    
    done = true;
    
    writeln("Phase: Test run completed!\n*************************************************************");

    return new shared TestResult(score, maxScore, description);

    /* Old version

    writeln(mode + " test results:\nGoal: " + efficiencyGoal + "\nActual: " + efficiencyMeasure);
    if (efficiencyMeasure <= efficiencyGoal) {
        writeln("Passed the " + mode + " test!  Great Job!");
    } else {
        writeln("Failed the " + mode + " test!  Hmmmmm...");
    }
    */

}


//This represents the result of a test.
class TestResult {
    var score : int;
    var maxScore : int;
    var description : string;

    proc init(score: int, maxScore : int, description : string) {
        this.score = score;
        this.maxScore = maxScore;
        this.description = description;
    }

    proc init(resultA : TestResult, resultB : TestResult) {
        this.score = resultA.getScore() + resultB.getScore();
        this.maxScore = resultA.getMaxScore() + resultB.getMaxScore();
        this.description = resultA.getDescription() + "\n\n" + resultB.getDescription();
    }

    proc getScore() : int {
        return this.score;
    }

    proc getMaxScore() : int {
        return this.maxScore;
    }

    proc getDescription() : string {
        return this.description;
    }

    proc writeThis(writer) {
        writer.writeln("Total tests score: " + this.getScore() + "/" + this.maxScore);
        writer.write(this.getDescription());
    }

}

proc getNumJobsProcessed(cpus : [] shared CPU) {
    var numJobs = 0;
    for cpu in cpus {
        numJobs += cpu.getNumJobsCompleted();
    }
    return numJobs;
}



//This represents a set of Jobs.  It is used to report stats about those jobs.
class JobGroup {

    var jobsDomain = {0..1};

    var jobs : [jobsDomain] shared Job;

    var numJobs : int;

    var synchronizer : owned Semaphore;

    proc init() {
        this.numJobs = 0;
        this.synchronizer = new owned Semaphore(1);
    }

    proc add(job : shared Job) {
        this.synchronizer.p();
        if (this.numJobs == this.jobsDomain.numIndices) {
            this.jobsDomain = {0..(this.jobsDomain.high * 2)};
        }
        this.jobs[this.numJobs] = job;
        this.numJobs += 1;
        //writeln("Just added a job to the group:");
        //writeln(job);
        this.synchronizer.v();
    }

    proc allCompleted() : bool {
        var anyRunning = false; //debugging!
        for jobIndex in 0..(this.numJobs-1) {
            var job = this.jobs[jobIndex];
            if (!job.isDone()) {
                //Is this scaffolding, or are we keeping this?
                //writeln("Job #", jobIndex, " is still running.");
                //writeln("Job: ", job);
                anyRunning = true;
                //return false;
            }
        }
        return !anyRunning;
        //return true;
    }

    proc reportStats(statIndex : int) : real {
        //wait for the jobs to complete
        while (!this.allCompleted()) {
            writeln("Jobs are still running.");
            sleep(1);
        }

        var totalWaitTime = 0.0;
        var maxWaitTime = 0.0;

        for jobIndex in 0..(this.numJobs-1) {
            var job = this.jobs[jobIndex];
            totalWaitTime += job.getWaitTime();
            maxWaitTime = max(maxWaitTime, job.getWaitTime());
        }

        var avgWaitTime = totalWaitTime / this.numJobs;
        var hybridWaitTime = 5 * avgWaitTime + maxWaitTime;

        writeln("~~~~~~~~~~~~~~~~~~~~~~");
        writeln("Job stats calculated!");
        writeln(this.numJobs, " jobs completed!");
        writeln("Maximum wait time: ", maxWaitTime);
        writeln("Average wait time: ", avgWaitTime);
        writeln("Hybrid wait time (max + 5 x avg): ", hybridWaitTime);
        writeln("~~~~~~~~~~~~~~~~~~~~~~~");

        var stats : [0..2] real;
        stats = (maxWaitTime, avgWaitTime, hybridWaitTime);

        return stats[statIndex];
    }

} //end of JobGroup class
