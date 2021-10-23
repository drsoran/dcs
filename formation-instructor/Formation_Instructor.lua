local updateInterval = 0.1;

local function toAngleLR(heading, fromCoordinate, toCoordinate)

  local dir = fromCoordinate:GetDirectionVec3(toCoordinate);
  local angle = fromCoordinate:GetAngleDegrees(dir);
  local aspect = angle - heading;

  if aspect > 180 then
    aspect = aspect - 360;
  end

  if (aspect >= 0 and aspect <= 180) then
    return 90 - aspect;
  end

  if (aspect < 0 and aspect >= -180) then
    return 90 + aspect;
  end

  return aspect;
end

local function formatDistance(distanceInMeters)
  if (distanceInMeters < 1852) then -- 1 NM in m
    return string.format('%d FT', UTILS.Round(UTILS.MetersToFeet(distanceInMeters), 2));
  else
    return string.format('%.2f NM', UTILS.Round(UTILS.MetersToNM(distanceInMeters), 2));
  end
end

local function getAngleAndDist(student, instructor)
  local pFrom = student:GetCoordinate();
  local pTo = instructor:GetCoordinate();
  local dist = pFrom:Get2DDistance(pTo);
  local aspect = toAngleLR(instructor:GetHeading(), pFrom, pTo);

  return math.floor(aspect), dist
end

function FormationInstructor(groupName, instructorName, stud1, stud2, stud3, stud4)
  local instructorGroup = GROUP:FindByName(groupName);
  local instructor = UNIT:FindByName(instructorName);
  local student_1 = CLIENT:FindByName(stud1);
  local student_2 = CLIENT:FindByName(stud2);
  local student_3 = CLIENT:FindByName(stud3);
  local student_4 = CLIENT:FindByName(stud4);

  local student_1_score = {t = 0.0};
  local student_2_score = {t = 0.0};
  local student_3_score = {t = 0.0};
  local student_4_score = {t = 0.0};

  local updateTimer = nil;

  local function updateStudents()
    local student1Alive = student_1:IsAlive();
    local student2Alive = student_2:IsAlive();
    local student3Alive = student_3:IsAlive();
    local student4Alive = student_4:IsAlive();

    if (not student1Alive and not student2Alive and not student3Alive and not student4Alive) then
      return;
    end

    local report = REPORT:New();

    local function fmt(student, number, score)
      local angle, dist = getAngleAndDist(student, instructor);

      local inZone = angle >= 40 and angle <= 50;
      local inZoneMarker = " <<";

      if (inZone) then
        score.t = score.t + updateInterval
        if (math.floor(score.t) % 2 == 0) then
          inZoneMarker = "";
        end;
      end

      local angleDistFmt = string.format('%03d°, %s', angle, formatDistance(dist));
      return string.format("#%d %s: %s, T: %s%s", number, student:GetPlayer(), angleDistFmt, UTILS.SecondsToClock(score.t, true), inZoneMarker);
    end

    if (student1Alive) then
      report:Add("-----");
      report:Add(fmt(student_1, 1, student_1_score));
    else
      student_1_score = 0;
    end
    if (student2Alive) then
      report:Add("-----");
      report:Add(fmt(student_2, 2, student_2_score));
    else
      student_2_score = 0;
    end
    if (student3Alive) then
      report:Add("-----");
      report:Add(fmt(student_3, 3, student_3_score));
    else
      student_3_score = 0;
    end
    if (student4Alive) then
      report:Add("-----");
      report:Add(fmt(student_4, 4, student_4_score));
    else
      student_4_score = 0;
    end

    MESSAGE:New(report:Text(), 1, nil, true):ToBlue();
  end

  local function onStudentJoined()
    -- MESSAGE:New("Joined", 1):ToBlue();

    if (not instructorGroup:IsActive()) then
      instructorGroup:Activate();
    end

    if (not updateTimer) then
      -- MESSAGE:New("Start timer", 1):ToBlue();
      updateTimer = TIMER:New(updateStudents):Start(1, updateInterval, nil);
    end
  end

  student_1:Alive(onStudentJoined);
  student_2:Alive(onStudentJoined);
  student_3:Alive(onStudentJoined);
  student_4:Alive(onStudentJoined);
end
