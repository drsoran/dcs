local updateInterval = 0.1;

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
  self.distanceToInstructorFT = self.distanceToInstructorFT - 33; -- substract 2 times wingspan half of the Viper (2 * 16ft)
  self.angleToInstructor = math.floor(self:toAngleLR(instructor:GetHeading(), pFrom, pTo));
end

function Student:isInFormation()
  local position = self.formation.positions[self.number];
  local inSpot
    = self.angleToInstructor >= position.angles[1]
      and self.angleToInstructor <= position.angles[2]
      and self.distanceToInstructorFT >= position.distancesFT[1]
      and self.distanceToInstructorFT <= position.distancesFT[2];

  return inSpot;
end

----------------
-- Entry
----------------

local formations = {
  Formation:New(
    "Fingertip",
    "45°, 0-50ft separation",
    {
      [1] = Position:New({40, 50}, {0, 50}), -- angle range [°], distance range [ft]
      [2] = Position:New({40, 50}, {50, 100}),
      [3] = Position:New({40, 50}, {0, 50}),
      [4] = Position:New({40, 50}, {50, 100})
    }),

  Formation:New(
    "Route",
    "45°, 50-500ft separation",
    {
      [1] = Position:New({40, 50}, {30, 500}),
      [2] = Position:New({40, 50}, {530, 1000}),
      [3] = Position:New({40, 50}, {30, 500}),
      [4] = Position:New({40, 50}, {530, 1000})
    }),

  Formation:New(
    "Fighting Wing",
    "30-70°, 500-3000ft separation",
    {
      [1] = Position:New({30, 70}, {480, 3020}),
      [2] = Position:New({30, 70}, {1020, 6020}),
      [3] = Position:New({30, 70}, {480, 3020}),
      [4] = Position:New({30, 70}, {1020, 6020})
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
  local instructor_group = nil;
  local instructor_unit = nil;

  local student_clients = {
    CLIENT:FindByName(stud1),
    CLIENT:FindByName(stud2),
    CLIENT:FindByName(stud3),
    CLIENT:FindByName(stud4),
  };

  local students = {};

  local updateTimer = nil;

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

      if (instructor_group) then
        instructor_unit = nil;
        instructor_group:Destroy(false);
        instructor_group = nil;
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
        MENU_GROUP_COMMAND:New(group, formations[i].name, menu, function ()
          for j = 1, #students do
            students[j]:SetFormation(formation);
          end
          selectedFormation = formation;
        end);
      end
    end

    if (not instructor_group) then
      instructor_group = SPAWN:New(instructorGroupName):Spawn();
      instructor_unit = instructor_group:GetUnits()[1];
    end

    if (not updateTimer) then
      BASE:TraceClassMethod(Student.ClassName, "toAngleLR");
      updateTimer = TIMER:New(updateStudents):Start(1, updateInterval, nil);
    end

    student:SetFormation(formations[1]);
  end

  for i = 1, #student_clients do
    local student_client = student_clients[i];
    local student = Student:New(student_client, i);

    student_client:Alive(function () onStudentJoined(student) end);
    students[#students + 1] = student;
  end
end
