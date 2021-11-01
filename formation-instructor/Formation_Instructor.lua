local updateInterval = 0.1;

STTS.DIRECTORY="d:/DCS-SimpleRadio-Standalone";

--------------
-- Score
--------------

Score = {
  timeInFormation = 0
}

function Score:New()
  local o = {
    timeInFormation = 0
  };

  setmetatable(o, {__index = self});
  return o;
end

function Score:AddSecondsInFormation(seconds)
  self.timeInFormation = self.timeInFormation + seconds;
end

function Score:GetSecondsInFormation()
  return math.floor(self.timeInFormation);
end

function Score:Reset()
  self.timeInFormation = 0;
end

----------------
-- Formation
----------------

Position = {
  angles = {},
  distancesFT = {}
}

function Position:New(angles, distancesFT)
  local o = {
    angles = angles,
    distancesFT = distancesFT
  };

  setmetatable(o, {__index = self});
  return o;
end

Formation = {
  name = "",
  description = "",
  poitions = {}
}

function Formation:New(name, description, positions)
  local o = {
    name = name,
    description = description,
    positions = positions
  };

  setmetatable(o, {__index = self});
  return o;
end

function Formation:GetDescription()
  return string.format("%s: %s", self.name,  self.description);
end

----------------
-- Student
----------------

Student = {
  ClassName = "Student",
  score = nil,
  number = 0,
  client = nil,
  angleToInstructor = 0,
  distanceToInstructorFT = 0,
  formation = nil
}

function Student:New(client, number)
  local o = BASE:Inherit(self, BASE:New());

  o.score = Score:New();
  o.number = number;
  o.client = client;
  o.angleToInstructor = 0;
  o.distanceToInstructorFT = 0;
  o.formation = nil;

  -- o:TraceOn();
  -- BASE:TraceClassMethod(self.ClassName, "toAngleLR");

  return o;
end

function Student:IsAlive()
  return self.client:IsAlive();
end

function Student:GetScore()
  return self.score;
end

function Student:Update(instructor)
  self:calculateAngleAndDist(instructor);
end

function Student:SetFormation(formation)
  self.score:Reset();
  self.formation = formation;
end

function Student:GetFormation()
  return self.formation;
end

function Student:GetReportLine()
  local inZoneMarker = "    ";

  if (self.formation) then
    if (self:isInFormation()) then
      self.score:AddSecondsInFormation(updateInterval);
      if (self.score:GetSecondsInFormation() % 2 == 0) then
        inZoneMarker = ">> ";
      end
    end
  end

  local function formatDistance()
    if (self.distanceToInstructorFT < 6076) then -- 1 NM in ft
      return string.format('%d FT', self.distanceToInstructorFT);
    else
      return string.format('%.2f NM', UTILS.Round(self.distanceToInstructorFT / 6076.12, 2));
    end
  end

  local angleDistFmt = string.format('%03d°, %s', self.angleToInstructor, formatDistance());

  return string.format("%s#%d %s: %s, T: %s",
    inZoneMarker,
      self.number,
      self.client:GetPlayer(),
      angleDistFmt,
      UTILS.SecondsToClock(self.score:GetSecondsInFormation(), true));
end

function Student:toAngleLR(heading, from, to)
  local dir = from:GetDirectionVec3(to);

  self:T(string.format("Dir: %f, %f, %f", dir.x, dir.y, dir.z));
  self:T(string.format("Heading: %f", heading));

  local angle = from:GetAngleDegrees(dir);
  self:T(string.format("angle raw: %f", angle));

  local aspect = angle - heading;
  self:T(string.format("angle - h: %f", aspect));

  if aspect < -180 then
    aspect = 360 + aspect;
  elseif aspect > 180 then
      aspect = aspect - 360;
  end

  if (aspect >= 0 and aspect <= 180) then
    aspect = 90 - aspect;
  elseif (aspect < 0 and aspect >= -180) then
    aspect = 90 + aspect;
  end

  self:T(string.format("aspect: %f", aspect));

  return aspect;
end

function Student:calculateAngleAndDist(instructor)
  local pFrom = self.client:GetCoordinate();
  local pTo = instructor:GetCoordinate();
  self.distanceToInstructorFT = math.floor(UTILS.MetersToFeet(pFrom:Get2DDistance(pTo)));
  self.distanceToInstructorFT = self.distanceToInstructorFT - 33; -- substract 2 times wingspan/2 of the Viper (2 * 16ft)
  self.angleToInstructor = math.floor(self:toAngleLR(instructor:GetHeading(), pFrom, pTo));
end

function Student:GetAngleAndDistanceIndicators()
  local position = self.formation.positions[self.number];

  local angleIndicator = 0;
  if (self.angleToInstructor < position.angles[1]) then
    angleIndicator = -1; -- too far ahead
  elseif (self.angleToInstructor > position.angles[2]) then
    angleIndicator = 1;  -- too far behind
  end

  local distanceIndicator = 0;
  if (self.distanceToInstructorFT < position.distancesFT[1]) then
    distanceIndicator = -1; -- too close
  elseif (self.distanceToInstructorFT > position.distancesFT[2]) then
    distanceIndicator = 1; -- too far out
  end

  return angleIndicator, distanceIndicator;
end

function Student:isInFormation()
  local inAngle, inDistance = self:GetAngleAndDistanceIndicators();
  return inAngle == 0 and inDistance == 0;
end

----------------
-- InstructorAI
----------------

local Vocabulary = {
  ["EnterAhead"] = {
    [1] = "You are too far ahead, fall back."
  },
  ["Ahead"] = {
    [1] = "You are still too far ahead."
  },
  ["EnterBehind"] = {
    [1] = "You are too far behind, close up."
  },
  ["Behind"] = {
    [1] = "You are still too far behind."
  },
  ["EnterInSpot"] = {
    [1] = "You are right in spot!"
  },
  ["InSpot"] = {
    [1] = "You are still in spot! Keep up!"
  },
};

StudentFSM = {
  ClassName = "StudentFSM",
  instructorAi = nil,
  stduent = nil,
  secondsInSamePositon = 0,
  feedbackSeconds = 30,
};

function StudentFSM:New(instructorAi, student)
  local o = BASE:Inherit(self, FSM:New());
  o.instructorAi = instructorAi;
  o.student = student;

  o:SetStartState("Idle");

  -- in spot
  o:AddTransition("Ahead", "IsInSpot", "WaitStableInSpot");
  o:AddTransition("Behind", "IsInSpot", "WaitStableInSpot");
  o:AddTransition("WaitStableInSpot", "IsStable", "InSpot");
  o:AddTransition("WaitStableInSpot", "*", "*");
  o:AddTransition("InSpot", "IsInSpot", "InSpot");

  -- ahead
  o:AddTransition("*", "IsAhead", "Ahead");

  -- behind
  o:AddTransition("*", "IsBehind", "Behind");
  o:AddTransition("*", "Dead", "End");

  o:TraceOn();
  BASE:TraceClass(self.ClassName);

  return o;
end

function StudentFSM:onenterState(from, event, to)
  self:logTransition(from, to);
  if from == to then
    self.secondsInSamePositon = self.secondsInSamePositon + 1;
  else
    local stateVocabulary = Vocabulary["Enter" .. to];
    self.instructorAi:speak(self.student.number, stateVocabulary[1]);
    self.secondsInSamePositon = 0;
  end
end

function StudentFSM:onenterBehind(from, event, to)
  self:logTransition(from, to);
  if from == to then
    self.secondsInSamePositon = self.secondsInSamePositon + 1;
    if self.secondsInSamePositon % self.feedbackSeconds == 0 then
      self.instructorAi:speak(self.student.number, "You are still too far behind.");
    end
  else
    self.instructorAi:speak(self.student.number, "You are too far behind, close up.");
    self.secondsInSamePositon = 0;
  end
end

function StudentFSM:onenterAhead(from, event, to)
  self:logTransition(from, to);
  if from == to then
    self.secondsInSamePositon = self.secondsInSamePositon + 1;
    if self.secondsInSamePositon % self.feedbackSeconds == 0 then
      self.instructorAi:speak(self.student.number, "You are still too far ahead.");
    end
  else
    self.instructorAi:speak(self.student.number, "You are too far ahead, fall back.");
    self.secondsInSamePositon = 0;
  end
end

function StudentFSM:onenterWaitStableInSpot(from, event, to)
  self:logTransition(from, to);
  if from == to then
    return;
  end

  self.secondsInSamePositon = 0;
  self:__IsStable(3);
end

function StudentFSM:onenterInSpot(from, event, to)
  self:logTransition(from, to);
  if event == "IsStable" then
    self.instructorAi:speak(self.student.number, "You are right in spot!");
    self.secondsInSamePositon = 0;
  end
  if from == to then
    self.secondsInSamePositon = self.secondsInSamePositon + 1;
    if self.secondsInSamePositon % self.feedbackSeconds == 0 then
      self.instructorAi:speak(self.student.number, "You are still in spot! Keep up!");
    end
  else
    self.secondsInSamePositon = 0;
  end
end

function StudentFSM:onenterDead(from, event, to)
  self.secondsInSamePositon = 0;
end

function StudentFSM:logTransition(from, to)
  self:T(string.format("%s -> %s", from, to));
end

InstructorAI = {
  ClassName = "InstructorAI",
  instructor = nil,
  students = nil,
  fsms = {},
  formation = nil,
};

function InstructorAI:New(instructor, students)
  local o = BASE:Inherit(self, BASE:New());
  o.instructor = instructor;
  o.students = students;

  for i = 1, #students do
    local student = students[i];
    o.fsms[#o.fsms + 1] = StudentFSM:New(o, student);
  end

  o:TraceOn();
  BASE:TraceClass(self.ClassName);

  return o;
 end

function InstructorAI:SetFormation(formation)
  self.formation = formation;
  local s = string.format(
    "Our formation is %s. Keep an angle between %d and %d degrees and %d to %d feet separation.",
     formation.name,
     formation.positions[1].angles[1],
     formation.positions[1].angles[2],
     formation.positions[1].distancesFT[1],
     formation.positions[1].distancesFT[2]);

  self:speak(nil, s);
end

function InstructorAI:Update()
  self:T(string.format("Students: %d", #self.students));

  for i = 1, #self.students do
    local student = self.students[i];
    local fsm = self.fsms[i];

    if (student:IsAlive()) then
      local angleInd, distanceInd = student:GetAngleAndDistanceIndicators();
      if (angleInd == 0) then
        fsm:IsInSpot();
      elseif (angleInd < 0) then
        fsm:IsAhead();
      elseif (angleInd > 0) then
        fsm:IsBehind();
      end
    else
      fsm:Dead();
    end
  end
end

function InstructorAI:speak(number, message)
  local sentence;
  if (number) then
    sentence = string.format("%d, %s", number, message);
  else
    sentence = string.format("Flight, %s", message);
  end

  STTS.TextToSpeech(sentence, "127", "AM", "1.0", self.instructor:GetName(), "0", nil, -5, "male", "en-US");
end

----------------
-- Entry
----------------

local formations = {
  Formation:New(
    "Fingertip",
    "45°, 75ft separation",
    {
      [1] = Position:New({40, 50}, {0, 30}), -- angle range [°], distance range [ft]
      [2] = Position:New({40, 50}, {30, 90}),
      [3] = Position:New({40, 50}, {0, 30}),
      [4] = Position:New({40, 50}, {30, 90})
    }),

  Formation:New(
    "Route",
    "45°, 500ft separation",
    {
      [1] = Position:New({40, 50}, {450, 550}),
      [2] = Position:New({40, 50}, {900, 1100}),
      [3] = Position:New({40, 50}, {450, 550}),
      [4] = Position:New({40, 50}, {900, 1100})
    }),

  Formation:New(
    "Fighting Wing",
    "30-70°, 500-3000ft separation",
    {
      [1] = Position:New({25, 70}, {480, 3020}),
      [2] = Position:New({25, 70}, {1020, 6020}),
      [3] = Position:New({25, 70}, {480, 3020}),
      [4] = Position:New({25, 70}, {1020, 6020})
    }),

  Formation:New(
      "Fluid Four",
      "(-5)-5°, 6000-9000ft separation",
      {
        [1] = Position:New({30, 70}, {480, 3020}),
        [2] = Position:New({30, 70}, {1020, 6020}),
        [3] = Position:New({-5, 5}, {6000, 9000}),
        [4] = Position:New({30, 70}, {1020, 6020})
      })
};

function FormationInstructor(instructorGroupName, stud1, stud2, stud3, stud4)
  local instructor_group = GROUP:FindByName(instructorGroupName);
  local instructor_unit = instructor_group:GetUnits()[1];

  local student_clients = {
    CLIENT:FindByName(stud1),
    CLIENT:FindByName(stud2),
    CLIENT:FindByName(stud3),
    CLIENT:FindByName(stud4),
  };

  local students = {};

  local instructorAI = nil;

  local updateTimer = nil;
  local aiTimer = nil;

  local selectedFormation = formations[1];

  local menu = nil;

  local function updateStudents()
    local anyAlive = false;
    local report = REPORT:New();

    report:Add(selectedFormation:GetDescription());

    for i = 1, #students do
      local student = students[i];

      if (student:IsAlive()) then
        anyAlive = true;
        student:Update(instructor_unit);
        report:Add("-----");
        report:Add(student:GetReportLine());
      else
        student:GetScore():Reset();
      end
    end

    if (not anyAlive) then
      if (updateTimer) then
        updateTimer:Stop();
        updateTimer = nil;
      end
      if (aiTimer) then
        aiTimer:Stop();
        aiTimer = nil;
      end
      return;
    end

    MESSAGE:New(report:Text(), 1, nil, true):ToBlue();
  end

  local function onStudentJoined(student)
    if (not menu) then
      local group = student.client:GetGroup();
      menu = MENU_GROUP:New(group, "Select Formation");

      for i = 1, #formations do
        local formation = formations[i];
        MENU_GROUP_COMMAND:New(group, formations[i].name, menu,
        function ()
          instructorAI:SetFormation(formation);

          for j = 1, #students do
            students[j]:SetFormation(formation);
          end

          selectedFormation = formation;
        end);
      end
    end

    if (not instructor_group:IsActive()) then
      instructor_group:Activate();
      instructorAI = InstructorAI:New(instructor_unit, students);
      -- instructorAI:SetFormation(selectedFormation);
    end

    if (not updateTimer) then
      updateTimer = TIMER:New(updateStudents):Start(1, updateInterval, nil);
    end

    if (not aiTimer) then
      aiTimer = TIMER:New(function () instructorAI:Update() end):Start(1, 1, nil);
    end

    student:SetFormation(selectedFormation);
  end

  for i = 1, #student_clients do
    local student_client = student_clients[i];
    local student = Student:New(student_client, i);

    student_client:Alive(function () onStudentJoined(student) end);
    students[#students + 1] = student;
  end
end
